class_name EventBar
extends HBoxContainer
## A row of small icons along the bottom of the screen, each starting
## an event in the world. An icon is clicked with the mouse free (Esc)
## or pressed by its number key while walking; while its event runs it
## is dimmed and does nothing.

const ICON := 22

var _events: Array[Dictionary] = []     # {button, start: Callable, running: Callable}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = MOUSE_FILTER_IGNORE
	_place()


## Centred on the bottom edge at the row's own size, ten pixels up.
func _place() -> void:
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM, PRESET_MODE_MINSIZE, 10)


## Add an icon drawn by `draw` (a Callable taking an Image of ICON
## pixels square), named by `tip` on hover, that calls `start`;
## `running` answers whether its event is still under way.
func add_event(draw: Callable, tip: String, start: Callable, running: Callable) -> void:
	var img := Image.create_empty(ICON, ICON, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	draw.call(img)
	var button := Button.new()
	button.icon = ImageTexture.create_from_image(img)
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "%d · %s" % [_events.size() + 1, tip]
	button.custom_minimum_size = Vector2(ICON + 8, ICON + 8)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.14, 0.16, 0.7)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", style)
	var index := _events.size()
	button.pressed.connect(func() -> void: trigger(index))
	add_child(button)
	_events.append({"button": button, "start": start, "running": running})
	_place.call_deferred()


## Start event `index` (from 0) unless it is already running.
func trigger(index: int) -> void:
	if index < 0 or index >= _events.size():
		return
	var event: Dictionary = _events[index]
	if bool((event["running"] as Callable).call()):
		return
	(event["start"] as Callable).call()


func _process(_delta: float) -> void:
	for event in _events:
		var busy := bool((event["running"] as Callable).call())
		var button: Button = event["button"]
		button.disabled = busy
		button.modulate.a = 0.5 if busy else 1.0


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var n := key.physical_keycode - KEY_1
	if n >= 0 and n < mini(_events.size(), 9):
		trigger(n)
		get_viewport().set_input_as_handled()


## The first icon: three small lights in a triangle.
static func draw_orbs(img: Image) -> void:
	var c := Vector2(ICON, ICON) / 2.0
	for k in 3:
		var a := -PI / 2.0 + TAU * k / 3.0
		var p := c + Vector2(cos(a), sin(a)) * 5.5
		for y in ICON:
			for x in ICON:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(p)
				var v := clampf(1.0 - (d - 1.6) / 1.6, 0.0, 1.0)
				if v > 0.0:
					var old := img.get_pixel(x, y)
					var col := Color(1.0, 0.82, 0.55, maxf(old.a, v))
					img.set_pixel(x, y, col)
