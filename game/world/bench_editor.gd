class_name BenchEditor
extends Node3D
## Working at a workbench (Workshop). The view leaves the player's eyes
## and flies out to look down on the bench from above one side, the
## mouse freed to point with; on leaving it flies back. The player's body
## stays where it stood.
##
## The view turns about a point over the bench: right-drag turns it,
## the wheel brings it nearer or farther, WASD or a middle-drag slides
## it. One level of the bench's grid is the working level, drawn as a
## grid of faint lines: R and F (or Shift and the wheel) raise and lower
## it.
##
## The tray along the bottom holds the pieces (Workshop.PIECES); a click
## on one, or its number key, takes it up. It follows the pointer over
## the working level, settling into the cell under it, and a left click
## sets it down there. A piece that sends a beam is then aimed at once:
## its beam follows the pointer, settling on any piece the pointer is on,
## and a left click fixes it (a right click or Esc leaves it pointing
## away from the view, as it was set down).
##
## On a piece already standing: a left-drag moves it about its level (R
## and F take it up and down meanwhile); a left click on a lantern opens
## or closes its shutter; a right click opens its menu (aim it again,
## look through it, its delay for an hourglass or afterglow, remove it);
## Delete removes it. E or Tab leaves; so does Esc when nothing is in
## hand.

enum Mode { OFF, FLY_IN, IDLE, CARRY, AIM, DRAG, FLY_OUT }

const FLY_TIME := 0.7
const FOV := 50.0
const DRAG_START := 6.0                 # pixels moved before a press becomes a drag
const PAN_SPEED := 4.0                  # m/s at the starting distance
const START_DIST := 9.5
const MENU_AIM := 1
const MENU_LOOK := 2
const MENU_SHUTTER := 3
const MENU_REMOVE := 4
const MENU_DELAY := 10

var workshop: Workshop
var bench: Workbench = null
var mode := Mode.OFF
var level := 1

var _cam := Camera3D.new()
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.62
var _dist := START_DIST
var _fly_t := 0.0
var _fly_from := Transform3D()
var _fly_fov := 60.0
var _carry_key := ""
var _cell := Workbench.NO_CELL
var _hovered: Node3D = null
var _aim_piece: Node3D = null
var _aim_before := Vector2.ZERO
var _aim_point := Vector3.INF
var _press_piece: Node3D = null
var _press_at := Vector2.ZERO
var _left_down := false
var _right_down := false
var _right_moved := 0.0
var _middle_down := false
var _drag_piece: Node3D = null
var _ghost := MeshInstance3D.new()
var _ghost_mat := StandardMaterial3D.new()
var _grid := ImmediateMesh.new()
var _grid_view := MeshInstance3D.new()
var _grid_mat := StandardMaterial3D.new()
var _menu := PopupMenu.new()
var _menu_piece: Node3D = null
var _ui := CanvasLayer.new()
var _hint := Label.new()
var _level_label := Label.new()
var _pack := Button.new()
var _pack_armed := 0.0


func _init(shop: Workshop) -> void:
	workshop = shop
	name = "BenchEditor"


func _ready() -> void:
	_cam.top_level = true
	_cam.near = 0.05
	add_child(_cam)
	_ghost.top_level = true
	_ghost.visible = false
	var cube := BoxMesh.new()
	cube.size = Vector3(0.3, 0.36, 0.3)
	cube.material = _ghost_mat
	_ghost.mesh = cube
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(_ghost)
	_grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_mat.vertex_color_use_as_albedo = true
	_grid_view.mesh = _grid
	_grid_view.top_level = true
	_grid_view.visible = false
	_grid_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_view.extra_cull_margin = 64.0
	add_child(_grid_view)
	_build_ui()


## ---- coming and going ----------------------------------------------------

## Working at `b`: the view flies out from the player's eyes.
func begin(b: Workbench) -> void:
	var player := workshop.island.player
	bench = b
	bench.editing = true
	bench.show_label(false)
	player.look_held_by = self
	player.input_locked = true
	MouseMode.release()
	_fly_from = player.camera.global_transform
	_fly_fov = player.camera.fov
	_cam.global_transform = _fly_from
	_cam.fov = _fly_fov
	_cam.current = true
	_target = bench.to_global(Vector3(0, 1.0, 0))
	_yaw = player.global_rotation.y
	_pitch = 0.62
	_dist = START_DIST
	level = 1
	_fly_t = 0.0
	mode = Mode.FLY_IN
	_carry_key = ""
	_pack_armed = 0.0
	_pack.text = "Pack up the bench"
	_ui.visible = true
	_grid_view.visible = true


## Back to the player's eyes: whatever is in hand put down or back first.
func end() -> void:
	if mode == Mode.OFF or mode == Mode.FLY_OUT:
		return
	_settle()
	_set_hovered(null)
	workshop.light.spot = Vector3.INF
	_ui.visible = false
	_menu.hide()
	_ghost.visible = false
	_grid_view.visible = false
	_fly_from = _cam.global_transform
	_fly_fov = _cam.fov
	_fly_t = 0.0
	mode = Mode.FLY_OUT


func _finish() -> void:
	var player := workshop.island.player
	mode = Mode.OFF
	player.camera.current = true
	player.look_held_by = null
	player.input_locked = false
	MouseMode.capture()
	if is_instance_valid(bench):
		bench.editing = false
	bench = null
	workshop.changed()


## Whatever is in hand finished with: an aim left as it was, a dragged
## piece put back, a carried one put away.
func _settle() -> void:
	match mode:
		Mode.AIM:
			_cancel_aim()
		Mode.DRAG:
			_drop(false)
		Mode.CARRY:
			_carry("")


## ---- the view --------------------------------------------------------------

func _orbit() -> Transform3D:
	var b := Basis.from_euler(Vector3(-_pitch, _yaw, 0.0))
	return Transform3D(b, _target + b * Vector3(0, 0, _dist))


func _process(delta: float) -> void:
	match mode:
		Mode.OFF:
			return
		Mode.FLY_IN:
			_fly_t = minf(_fly_t + delta / FLY_TIME, 1.0)
			var e := smoothstep(0.0, 1.0, _fly_t)
			_cam.global_transform = _fly_from.interpolate_with(_orbit(), e)
			_cam.fov = lerpf(_fly_fov, FOV, e)
			if _fly_t >= 1.0:
				mode = Mode.IDLE
			_draw_grid()
			return
		Mode.FLY_OUT:
			var player := workshop.island.player
			_fly_t = minf(_fly_t + delta / FLY_TIME, 1.0)
			var e := smoothstep(0.0, 1.0, _fly_t)
			_cam.global_transform = _fly_from.interpolate_with(player.camera.global_transform, e)
			_cam.fov = lerpf(_fly_fov, player.camera.fov, e)
			if _fly_t >= 1.0:
				_finish()
			return
	if not is_instance_valid(bench):
		_finish()
		return
	if _pack_armed > 0.0:
		_pack_armed -= delta
		if _pack_armed <= 0.0:
			_pack.text = "Pack up the bench"
	_ui.visible = workshop.scope.held == null
	_grid_view.visible = workshop.scope.held == null
	if workshop.scope.held != null:
		return
	_slide(delta)
	_cam.global_transform = _orbit()
	_cam.fov = FOV
	_point()
	_draw_grid()
	_update_hint()


## WASD slides the view's middle about over the bench, kept near it.
func _slide(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1.0
	if move != Vector2.ZERO:
		_pan(move.normalized() * PAN_SPEED * delta * _dist / START_DIST)


## The view's middle moved by `by` (x right, y back) in the flat.
func _pan(by: Vector2) -> void:
	var b := Basis(Vector3.UP, _yaw)
	_target += b * Vector3(by.x, 0.0, by.y)
	var local := bench.to_local(_target)
	var reach := Workbench.SIZE * 0.5 + 2.0
	local.x = clampf(local.x, -reach, reach)
	local.z = clampf(local.z, -reach, reach)
	local.y = 1.0
	_target = bench.to_global(local)


## ---- the pointer ----------------------------------------------------------

## What is under the pointer: a piece, the cell at the working level, and
## while carrying, dragging or aiming, the piece in hand follows it.
func _point() -> void:
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var mp := get_viewport().get_mouse_position()
	var o := _cam.project_ray_origin(mp)
	var d := _cam.project_ray_normal(mp)
	var space := get_world_3d().direct_space_state
	var hovered: Node3D = null
	if not over_ui:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 80.0, 4)
		var skip: Array[RID] = []
		for n: Node3D in [_aim_piece, _drag_piece]:
			if n != null and is_instance_valid(n):
				skip.append((n as CollisionObject3D).get_rid())
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and workshop.is_piece(hit["collider"]):
			hovered = hit["collider"] as Node3D
	_set_hovered(hovered)
	_cell = Workbench.NO_CELL if over_ui else _cell_under(o, d, level)
	match mode:
		Mode.CARRY:
			_ghost.visible = _cell != Workbench.NO_CELL
			if _ghost.visible:
				_ghost.global_position = bench.to_global(Workbench.cell_point(_cell))
				_ghost.global_rotation = bench.global_rotation
				var colour: Color = Workshop.GLASS_COLOUR
				if Workshop.KINDS.has(_carry_key):
					colour = LumenPart.COLOURS[Workshop.KINDS[_carry_key]]
				_ghost_mat.albedo_color = Color(colour, 0.5) if bench.is_free(_cell) else Color(1.0, 0.2, 0.15, 0.5)
		Mode.DRAG:
			var home: Vector3i = bench.cells[_drag_piece]
			var at := _cell if bench.is_free(_cell, _drag_piece) else home
			_drag_piece.position = Workbench.cell_point(at)
		Mode.AIM:
			if not is_instance_valid(_aim_piece):
				mode = Mode.IDLE
				return
			if over_ui:
				return
			var point := Vector3.INF
			if hovered != null:
				point = hovered.global_position
			else:
				var q2 := PhysicsRayQueryParameters3D.create(o, o + d * 80.0)
				q2.exclude = [(_aim_piece as CollisionObject3D).get_rid()]
				var hit2 := space.intersect_ray(q2)
				if not hit2.is_empty():
					point = hit2["position"]
				else:
					point = o + d * 12.0
			_aim_point = point
			workshop.aim_at(_aim_piece, point)
			workshop.light.spot = point
			workshop.light.spot_size = 0.06 * _cam.global_position.distance_to(point) / START_DIST * 2.0


## The cell at `lvl` the pointer's ray from `o` along `d` passes through.
func _cell_under(o: Vector3, d: Vector3, lvl: int) -> Vector3i:
	var lo := bench.to_local(o)
	var ld := bench.global_basis.inverse() * d
	if absf(ld.y) < 0.0001:
		return Workbench.NO_CELL
	var t := (lvl * Workbench.PITCH - lo.y) / ld.y
	if t <= 0.0:
		return Workbench.NO_CELL
	return Workbench.cell_near(lo + ld * t, lvl)


func _set_hovered(piece: Node3D) -> void:
	if piece == _hovered:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.call("show_label", false)
	_hovered = piece
	if piece != null:
		piece.call("show_label", true)


## ---- the working level's grid --------------------------------------------

## The working level's cells as faint lines, the pieces standing on it
## marked, and the cell under the pointer drawn bright with a line down
## to the deck.
func _draw_grid() -> void:
	_grid.clear_surfaces()
	if not is_instance_valid(bench):
		return
	_grid_view.global_transform = bench.global_transform
	var y := level * Workbench.PITCH
	var half := Workbench.SIZE * 0.5
	var faint := Color(1.0, 1.0, 1.0, 0.16)
	var lines := PackedVector3Array()
	var colours := PackedColorArray()
	for n in Workbench.CELLS + 1:
		var c := -half + n * Workbench.PITCH
		var edge := n == 0 or n == Workbench.CELLS
		var col := Color(1.0, 0.95, 0.8, 0.45) if edge else faint
		lines.append_array([Vector3(c, y, -half), Vector3(c, y, half), Vector3(-half, y, c), Vector3(half, y, c)])
		colours.append_array([col, col, col, col])
	for cell: Vector3i in bench.pieces:
		if cell.y == level:
			_square(lines, colours, Workbench.cell_point(cell), 0.2, Color(1.0, 0.9, 0.6, 0.55))
	if (mode == Mode.CARRY or mode == Mode.DRAG) and _cell != Workbench.NO_CELL:
		var p := Workbench.cell_point(_cell)
		var bright := Color(1.0, 1.0, 0.85, 0.9)
		_square(lines, colours, p, 0.24, bright)
		_square(lines, colours, Vector3(p.x, 0.01, p.z), 0.2, Color(1.0, 1.0, 0.85, 0.5))
		lines.append_array([Vector3(p.x, 0.01, p.z), Vector3(p.x, y, p.z)])
		colours.append_array([Color(1.0, 1.0, 0.85, 0.5), Color(1.0, 1.0, 0.85, 0.5)])
	_grid.surface_begin(Mesh.PRIMITIVE_LINES, _grid_mat)
	for k in lines.size():
		_grid.surface_set_color(colours[k])
		_grid.surface_add_vertex(lines[k])
	_grid.surface_end()


func _square(lines: PackedVector3Array, colours: PackedColorArray, at: Vector3, r: float, col: Color) -> void:
	var c := [at + Vector3(-r, 0, -r), at + Vector3(r, 0, -r), at + Vector3(r, 0, r), at + Vector3(-r, 0, r)]
	for k in 4:
		lines.append_array([c[k], c[(k + 1) % 4]])
		colours.append_array([col, col])


## ---- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.OFF or mode == Mode.FLY_OUT or workshop.scope.held != null:
		return
	if mode == Mode.FLY_IN:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			end()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		if not _key(event as InputEventKey):
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _motion(m: InputEventMouseMotion) -> void:
	if _right_down:
		_right_moved += m.relative.length()
		if _right_moved > 4.0:
			_yaw -= m.relative.x * 0.006
			_pitch = clampf(_pitch + m.relative.y * 0.006, 0.08, 1.45)
	if _middle_down:
		_pan(Vector2(-m.relative.x, -m.relative.y) * 0.004 * _dist)
	if _left_down and mode == Mode.IDLE and _press_piece != null and bench.cells.has(_press_piece) \
			and m.position.distance_to(_press_at) > DRAG_START:
		_drag_piece = _press_piece
		_press_piece = null
		level = (bench.cells[_drag_piece] as Vector3i).y
		mode = Mode.DRAG


func _button(b: InputEventMouseButton) -> void:
	match b.button_index:
		MOUSE_BUTTON_LEFT:
			_left_down = b.pressed
			if b.pressed:
				match mode:
					Mode.CARRY:
						_set_down()
					Mode.AIM:
						_fix_aim()
					Mode.IDLE:
						_press_piece = _hovered
						_press_at = b.position
			else:
				if mode == Mode.DRAG:
					_drop(true)
				elif mode == Mode.IDLE and _press_piece != null and _press_piece == _hovered:
					if _press_piece is LumenPart and (_press_piece as LumenPart).kind == LumenPart.Kind.LANTERN:
						workshop.toggle(_press_piece as LumenPart)
				_press_piece = null
		MOUSE_BUTTON_RIGHT:
			_right_down = b.pressed
			if b.pressed:
				_right_moved = 0.0
			elif _right_moved <= 4.0:
				match mode:
					Mode.AIM:
						_cancel_aim()
					Mode.CARRY:
						_carry("")
					Mode.IDLE:
						if _hovered != null:
							_open_menu(_hovered, b.position)
		MOUSE_BUTTON_MIDDLE:
			_middle_down = b.pressed
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not b.pressed:
				return
			var up := b.button_index == MOUSE_BUTTON_WHEEL_UP
			if b.shift_pressed:
				_step_level(1 if up else -1)
			else:
				_dist = clampf(_dist * (0.88 if up else 1.0 / 0.88), 2.5, 30.0)


## Keys: whether it was one of the editor's.
func _key(k: InputEventKey) -> bool:
	if not k.pressed or k.echo:
		return k.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]
	if k.is_action_pressed("interact") or k.physical_keycode == KEY_TAB:
		end()
		return true
	if k.is_action_pressed("ui_cancel"):
		if mode == Mode.IDLE:
			end()
		else:
			_settle()
		return true
	match k.physical_keycode:
		KEY_R:
			_step_level(1)
		KEY_F:
			_step_level(-1)
		KEY_DELETE, KEY_BACKSPACE, KEY_X:
			if mode == Mode.IDLE and _hovered != null and bench.cells.has(_hovered):
				_remove(_hovered)
		KEY_W, KEY_A, KEY_S, KEY_D:
			pass
		_:
			var n := k.physical_keycode - KEY_1 if k.physical_keycode != KEY_0 else 9
			if n >= 0 and n <= 9 and (k.physical_keycode >= KEY_0 and k.physical_keycode <= KEY_9):
				_carry(str(Workshop.PIECES[n][0]))
			else:
				return false
	return true


func _step_level(by: int) -> void:
	level = clampi(level + by, 1, Workbench.LEVELS)
	_level_label.text = "Level %d of %d  (%.1f m)" % [level, Workbench.LEVELS, level * Workbench.PITCH]


## ---- building ----------------------------------------------------------------

## A piece of `key` taken up from the tray (or put back: "").
func _carry(key: String) -> void:
	if mode == Mode.AIM:
		_fix_aim()
	if mode != Mode.IDLE and mode != Mode.CARRY:
		return
	_carry_key = key
	mode = Mode.CARRY if key != "" else Mode.IDLE
	_ghost.visible = false


## The carried piece set down in the cell under the pointer, its beam
## then aimed.
func _set_down() -> void:
	if _cell == Workbench.NO_CELL or not bench.is_free(_cell):
		return
	# Set down pointing away from the view.
	var f := bench.global_basis.inverse() * -_cam.global_basis.z
	var piece := bench.add_piece(_carry_key, _cell, atan2(-f.x, -f.z), 0.0)
	workshop.changed()
	_carry_key = ""
	_ghost.visible = false
	mode = Mode.IDLE
	if Workshop.sends(piece):
		_start_aim(piece)


func _start_aim(piece: Node3D) -> void:
	_aim_piece = piece
	_aim_before = Vector2(float(piece.get("yaw")), float(piece.get("pitch")))
	_aim_point = Vector3.INF
	workshop.light.held = piece
	mode = Mode.AIM


func _fix_aim() -> void:
	_end_aim()
	workshop.changed()


func _cancel_aim() -> void:
	if is_instance_valid(_aim_piece):
		_aim_piece.call("aim", _aim_before.x, _aim_before.y)
	_end_aim()


func _end_aim() -> void:
	_aim_piece = null
	workshop.light.held = null
	workshop.light.spot = Vector3.INF
	mode = Mode.IDLE


## The dragged piece set down in the cell under the pointer (`keep`), or
## put back where it was.
func _drop(keep: bool) -> void:
	var home: Vector3i = bench.cells[_drag_piece]
	if keep and _cell != Workbench.NO_CELL and bench.is_free(_cell, _drag_piece) and _cell != home:
		bench.move_piece(_drag_piece, _cell)
		workshop.changed()
	else:
		_drag_piece.position = Workbench.cell_point(home)
	_drag_piece = null
	mode = Mode.IDLE


func _remove(piece: Node3D) -> void:
	_set_hovered(null)
	bench.remove_piece(piece)
	workshop.changed()


## ---- a piece's menu ----------------------------------------------------------

func _open_menu(piece: Node3D, at: Vector2) -> void:
	_menu_piece = piece
	_menu.clear()
	# Drafts.
	if Workshop.sends(piece):
		_menu.add_item("Aim it", MENU_AIM)
		_menu.add_item("Look through it", MENU_LOOK)
	if piece is LumenPart:
		var p := piece as LumenPart
		if p.kind == LumenPart.Kind.LANTERN:
			_menu.add_item("Close the shutter" if p.condition else "Open the shutter", MENU_SHUTTER)
		if p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF:
			_menu.add_separator("Delay")
			for i in Workshop.DELAYS.size():
				var d: float = Workshop.DELAYS[i]
				_menu.add_radio_check_item("%d seconds" % roundi(d), MENU_DELAY + i)
				_menu.set_item_checked(_menu.get_item_count() - 1, is_equal_approx(p.delay, d))
	_menu.add_separator()
	_menu.add_item("Remove it", MENU_REMOVE)
	_menu.reset_size()
	_menu.popup(Rect2i(Vector2i(at) + Vector2i(4, 4), Vector2i.ZERO))


func _on_menu(id: int) -> void:
	var piece := _menu_piece
	_menu_piece = null
	if piece == null or not is_instance_valid(piece) or mode != Mode.IDLE:
		return
	match id:
		MENU_AIM:
			_start_aim(piece)
		MENU_LOOK:
			workshop.scope.enter(piece, _cam)
		MENU_SHUTTER:
			workshop.toggle(piece as LumenPart)
		MENU_REMOVE:
			_remove(piece)
		_:
			var i := id - MENU_DELAY
			if i >= 0 and i < Workshop.DELAYS.size():
				var p := piece as LumenPart
				p.delay = Workshop.DELAYS[i]
				workshop.relabel(p)
				workshop.changed()


## ---- the tray and the hints --------------------------------------------------

func _build_ui() -> void:
	_ui.layer = 6
	_ui.visible = false
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 13
	root.theme = theme
	_ui.add_child(root)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.72)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	# The tray along the bottom.
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", style)
	tray.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tray.offset_bottom = -10.0
	root.add_child(tray)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	tray.add_child(row)
	for i in Workshop.PIECES.size():
		var key: String = Workshop.PIECES[i][0]
		var b := Button.new()
		b.text = ("%s\n%d" % [Workshop.PIECES[i][1], (i + 1) % 10]) if i < 10 else "%s\n " % Workshop.PIECES[i][1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(72, 44)
		var colour: Color = LumenPart.COLOURS[Workshop.KINDS[key]] if Workshop.KINDS.has(key) else Workshop.GLASS_COLOUR
		b.icon = _swatch(colour)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func() -> void: _carry(key))
		row.add_child(b)
	# The hint above it.
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_bottom = -92.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	# The level and the bench, at the right.
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", style)
	side.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.offset_right = -12.0
	root.add_child(side)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	side.add_child(col)
	_level_label.text = "Level 1 of %d  (0.5 m)" % Workbench.LEVELS
	col.add_child(_level_label)
	var ups := HBoxContainer.new()
	col.add_child(ups)
	for step: int in [1, -1]:
		var b := Button.new()
		b.text = "Up  (R)" if step > 0 else "Down  (F)"
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _step_level(step))
		ups.add_child(b)
	var done := Button.new()
	done.text = "Done  (E)"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(end)
	col.add_child(done)
	_pack.text = "Pack up the bench"
	_pack.focus_mode = Control.FOCUS_NONE
	_pack.pressed.connect(_pack_up)
	col.add_child(_pack)
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)


func _swatch(colour: Color) -> ImageTexture:
	var img := Image.create(28, 6, false, Image.FORMAT_RGBA8)
	img.fill(colour)
	return ImageTexture.create_from_image(img)


## Pack up asks once more before the bench and everything on it goes.
func _pack_up() -> void:
	if _pack_armed <= 0.0:
		_pack_armed = 3.0
		_pack.text = "Click again to pack up"
		return
	var b := bench
	end()
	workshop.remove_bench(b)


## What the hint line says, for what is in hand. Drafts.
func _update_hint() -> void:
	var text := ""
	match mode:
		Mode.IDLE:
			text = "Take a piece from the tray, or press its number.     Right-drag: turn round     Wheel: nearer, farther     WASD: slide\nOn a piece: drag to move it     click a lantern to open or close it     right click for more     Delete: remove it"
		Mode.CARRY:
			var name_of := ""
			for p: Array in Workshop.PIECES:
				if p[0] == _carry_key:
					name_of = p[1]
			text = "Left click: set the %s down here     R / F: up or down a level     Right click or Esc: put it back" % name_of
			if _cell != Workbench.NO_CELL and not bench.is_free(_cell):
				text = "That place is taken.     " + text
		Mode.AIM:
			text = "Left click where its beam should go, or on a piece     Right click or Esc: leave it as it was"
			if _hovered is LumenPart and (_hovered as LumenPart).kind == LumenPart.Kind.LATCH:
				var latch := _hovered as LumenPart
				var right := latch.global_transform.basis * (Basis.from_euler(Vector3(latch.pitch, latch.yaw, 0.0)) * Vector3.RIGHT)
				var dir := (latch.global_position - _aim_piece.global_position).normalized()
				text = ("The beam strikes the latch from its left: it will light it.\n" if dir.dot(right) > 0.0
						else "The beam strikes the latch from its right: it will put it out.\n") + text
		Mode.DRAG:
			text = "Let go to set it down     R / F: up or down a level"
	_hint.text = text
