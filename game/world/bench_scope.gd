class_name BenchScope
extends Node3D
## Looking through a piece the player built to aim it (Workshop), as at the beam
## range (OpticBench): from a crystal's or lantern's lens along its beam;
## from a mirror or splitter along the beam it sends on, so steering the
## view turns the glass to send the beam there; from a lens along its
## axis. The mouse aims (finer as the view narrows), the wheel zooms, a
## glowing spot marks where the beam strikes; E or Esc looks out again
## through the player's eyes. A beam passing within SNAP metres of the middle of
## another piece settles there with a click; a firm push frees it.

const SNAP := 0.2
const FOV_START := 40.0

var workshop: Workshop
var held: Node3D = null

var _cam := Camera3D.new()
var _overlay := CanvasLayer.new()
var _back: Camera3D
var _was_captured := false
var _was_locked := false
var _was_held: Object = null
var _fov := FOV_START
var _snapped := false
var _snap_drag := 0.0
var _broken_from := Vector3.INF
var _snap_piece: Node3D = null          # the piece the beam last settled on
var _turned := false                    # turned by the mouse since entering
var _click := AudioStreamPlayer3D.new()


func _init(shop: Workshop) -> void:
	workshop = shop
	name = "BenchScope"


func _ready() -> void:
	_cam.near = 0.03
	_cam.top_level = true
	add_child(_cam)
	_overlay.layer = 20
	_overlay.visible = false
	add_child(_overlay)
	var frame := TextureRect.new()
	frame.texture = OpticBench.scope_picture()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(frame)
	var hint := Label.new()
	hint.text = "Mouse: aim     Wheel: zoom     E: done"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 46.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(hint)
	_click.stream = load("res://audio/ratchet.wav") if DisplayServer.get_name() != "headless" else null
	_click.unit_size = 3.0
	_click.top_level = true
	add_child(_click)


## Looking through `piece`; on leaving, the view goes back to `back`.
func enter(piece: Node3D, back: Camera3D) -> void:
	var player := workshop.island.player
	held = piece
	_back = back
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_was_locked = player.input_locked
	_was_held = player.look_held_by
	player.input_locked = true
	player.look_held_by = self
	MouseMode.capture()
	workshop.light.held = piece
	_fov = FOV_START
	_snapped = false
	_snap_piece = null
	_turned = false
	_broken_from = Vector3.INF
	_place()
	_cam.current = true
	_overlay.visible = true


func leave() -> void:
	if held == null:
		return
	var player := workshop.island.player
	workshop.aimed_by_scope(held, _snap_piece if _snapped else null, _turned)
	held = null
	workshop.light.held = null
	workshop.light.spot = Vector3.INF
	player.input_locked = _was_locked
	player.look_held_by = _was_held
	MouseMode.set_captured(_was_captured)
	if is_instance_valid(_back):
		_back.current = true
	_overlay.visible = false
	workshop.changed()


func _unhandled_input(event: InputEvent) -> void:
	if held == null:
		return
	if event is InputEventMouseMotion:
		_turn_by((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			_fov = clampf(_fov * (0.8 if b == MOUSE_BUTTON_WHEEL_UP else 1.25), 1.5, 60.0)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		leave()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held):
		leave()
		return
	_place()
	var light := workshop.light
	light.spot = light.struck
	if light.struck != Vector3.INF:
		light.spot_size = _cam.global_position.distance_to(light.struck) * tan(deg_to_rad(_fov * 0.5)) * 0.025


func _physics_process(_delta: float) -> void:
	if held != null and is_instance_valid(held) and not _snapped:
		_try_snap()


## Which way the held piece sends its beam: a crystal or lantern along
## its lens; a mirror or splitter the beam reaching it turned off its
## face (or its face's direction when none reaches it); a lens along its
## axis.
func _sending_dir() -> Vector3:
	if held is OpticElement:
		var e := held as OpticElement
		var n := e.normal()
		if e.kind != OpticElement.Kind.LENS and workshop.light.arrivals.has(e):
			var incoming: Vector3 = (workshop.light.arrivals[e] as Array)[1]
			return (incoming - 2.0 * incoming.dot(n) * n).normalized()
		return n
	return (held as LumenPart).forward()


func _place() -> void:
	var dir := _sending_dir()
	var from: Vector3
	if held is LumenPart:
		from = (held as LumenPart).lens_point()
	else:
		var e := held as OpticElement
		if e.kind != OpticElement.Kind.LENS and workshop.light.arrivals.has(e):
			from = (workshop.light.arrivals[e] as Array)[0]
		else:
			from = e.global_position + dir * 0.06
	from += dir * 0.04
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	_cam.global_transform = Transform3D(Basis.looking_at(dir, up), from)
	_cam.fov = _fov


func _turn_by(motion: Vector2) -> void:
	if _snapped:
		_snap_drag += motion.length()
		if _snap_drag < 45.0:
			return
		_snapped = false
	_turned = true
	var fine := motion * (_fov / 60.0)
	if held is LumenPart:
		(held as LumenPart).turn_by(fine)
		return
	var e := held as OpticElement
	if e.kind != OpticElement.Kind.LENS and workshop.light.arrivals.has(e):
		var d := _sending_dir()
		var yaw := atan2(-d.x, -d.z) - fine.x * 0.004
		var pitch := clampf(asin(clampf(d.y, -1.0, 1.0)) - fine.y * 0.004, -1.2, 1.2)
		var out := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD
		var incoming: Vector3 = (workshop.light.arrivals[e] as Array)[1]
		e.aim_along((out - incoming).normalized())
	else:
		e.turn_by(fine)


## The beam passing close by the middle of another piece settles there.
func _try_snap() -> void:
	var origin: Vector3
	var out_dir: Vector3
	if held is LumenPart:
		origin = (held as LumenPart).lens_point()
		out_dir = (held as LumenPart).forward()
	elif (held as OpticElement).kind != OpticElement.Kind.LENS and workshop.light.arrivals.has(held):
		origin = (workshop.light.arrivals[held] as Array)[0]
		out_dir = _sending_dir()
	else:
		return
	var best := Vector3.INF
	var best_piece: Node3D = null
	var best_perp := SNAP
	for piece in workshop.all_pieces():
		if piece == held:
			continue
		var target := piece.global_position
		var t := (target - origin).dot(out_dir)
		if t < 0.3 or t > BenchLight.REACH * 2.0:
			continue
		var perp := (origin + out_dir * t).distance_to(target)
		if perp < best_perp:
			best_perp = perp
			best = target
			best_piece = piece
	if _broken_from != Vector3.INF:
		var away := INF
		var t2 := (_broken_from - origin).dot(out_dir)
		if t2 > 0.0:
			away = (origin + out_dir * t2).distance_to(_broken_from)
		if away > SNAP * 1.5:
			_broken_from = Vector3.INF
	if best == Vector3.INF or best.is_equal_approx(_broken_from):
		return
	workshop.aim_at(held, best)
	_snap_piece = best_piece
	_snapped = true
	_snap_drag = 0.0
	_broken_from = best
	_click.global_position = held.global_position
	BeachSite._play(_click, 1.6)
