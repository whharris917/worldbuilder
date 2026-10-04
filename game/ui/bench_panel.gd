class_name BenchPanel
extends CanvasLayer
## Panels of controls for a study scene, as the one-bulb scene lays them
## out: a row of buttons at the top left, each opening its panel below
## them, one panel at most open; a count of frames a second at the top
## right. Text at 13 px, notes at 11. A panel scrolls when taller than
## the window. Used with the mouse freed by Esc.
##
## Every control is registered by its title, and its setting is kept in
## a JSON file: written half a second after the last change and on
## leaving, read back by `restore` on arrival. A control added later
## starts at its default and one removed is ignored. Probes and headless
## runs neither read nor write it.

const COLUMN_W := 240.0
const FONT_SIZE := 13
const NOTE_SIZE := 11

var sliders: Dictionary = {}           # title -> HSlider
var switches: Dictionary = {}          # title -> CheckButton
var choices: Dictionary = {}           # title -> {option -> CheckBox}
var pickers: Dictionary = {}           # title -> ColorPickerButton

var _state_path := ""
var _root: Control
var _row: HBoxContainer
var _group := ButtonGroup.new()
var _scrolls: Array[ScrollContainer] = []
var _fps: Label
var _save_in := -1.0                    # seconds to the next write; below 0, nothing to write
var _restoring := false


func _init(state_path: String) -> void:
	_state_path = state_path
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_root.theme = theme
	add_child(_root)
	_row = HBoxContainer.new()
	_row.position = Vector2(16, 16)
	_root.add_child(_row)
	_group.allow_unpress = true
	_fps = Label.new()
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -120.0
	_fps.offset_right = -16.0
	_fps.offset_top = 12.0
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_fps)


## A new panel, closed, with its button in the row; its column of
## controls, to fill.
func panel(title: String) -> VBoxContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(16, 48)
	frame.visible = false
	_root.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_scrolls.append(scroll)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 12)      # clear of the scroll bar
	scroll.add_child(gutter)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_W, 0)
	column.add_theme_constant_override("separation", 2)
	gutter.add_child(column)
	var tab := Button.new()
	tab.text = title
	tab.toggle_mode = true
	tab.button_group = _group
	tab.focus_mode = Control.FOCUS_NONE
	tab.toggled.connect(func(on: bool) -> void: frame.visible = on)
	_row.add_child(tab)
	return column


func box(column: VBoxContainer) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 2)
	column.add_child(b)
	return b


func heading(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	column.add_child(label)


func note(column: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(COLUMN_W, 0)
	label.add_theme_font_size_override("font_size", NOTE_SIZE)
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	column.add_child(label)
	return label


## A label and a colour swatch on one row.
func colour(column: VBoxContainer, title: String, value: Color, on_change: Callable) -> ColorPickerButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(48, 22)
	picker.color = value
	picker.color_changed.connect(func(c: Color) -> void:
		on_change.call(c)
		_changed())
	row.add_child(picker)
	column.add_child(row)
	pickers[title] = picker
	return picker


## A row of options of which exactly one is chosen, `first` to begin.
func choice(column: VBoxContainer, title: String, options: Array, first: String, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(56, 0)
	row.add_child(label)
	var group := ButtonGroup.new()
	var boxes := {}
	for option: String in options:
		var b := CheckBox.new()
		b.text = option
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = option == first
		b.toggled.connect(func(on: bool) -> void:
			if on:
				on_pick.call(option)
				_changed())
		row.add_child(b)
		boxes[option] = b
	choices[title] = boxes
	column.add_child(row)


func pick(title: String, option: String) -> void:
	(choices[title][option] as CheckBox).button_pressed = true


func switch(column: VBoxContainer, title: String, on: bool, on_toggle: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.button_pressed = on
	button.toggled.connect(func(v: bool) -> void:
		on_toggle.call(v)
		_changed())
	switches[title] = button
	column.add_child(button)
	return button


## A label and its slider on one row; the label shows the value.
func slider(column: VBoxContainer, title: String, lo: float, hi: float, step: float,
		value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var s := HSlider.new()
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	var show := func(v: float) -> void:
		label.text = "%s: %s" % [title, str(int(v)) if step >= 1.0 else "%.2f" % v]
	show.call(value)
	s.value_changed.connect(func(v: float) -> void:
		show.call(v)
		on_change.call(v)
		_changed())
	sliders[title] = s
	row.add_child(s)
	column.add_child(row)
	return s


## A plain button that runs `on_press`.
func button(column: VBoxContainer, title: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_press)
	column.add_child(b)
	return b


## Dimmed and inert, or live: every control under a box.
func enable(b: Control, on: bool) -> void:
	b.modulate.a = 1.0 if on else 0.35
	for node in b.find_children("*", "", true, false):
		if node is HSlider:
			(node as HSlider).editable = on
		elif node is BaseButton:
			(node as BaseButton).disabled = not on


func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	_fps.text = "%d fps  %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]
	if _save_in >= 0.0:
		_save_in -= delta
		if _save_in < 0.0:
			save()
	# The open panel stands as tall as its controls, up to the bottom of
	# the window less a margin; beyond that it scrolls.
	var room := get_viewport().get_visible_rect().size.y - 48.0 - 16.0 - 16.0
	for scroll in _scrolls:
		if not scroll.is_visible_in_tree():
			continue
		var want := minf((scroll.get_child(0) as Control).get_combined_minimum_size().y, room)
		if absf(scroll.custom_minimum_size.y - want) > 0.5:
			scroll.custom_minimum_size = Vector2(0.0, want)
			(scroll.get_parent() as Control).reset_size()


## ---- remembering the controls --------------------------------------------

## Extra settings a scene keeps that no control holds (a key's state),
## read and written with the rest.
var extra: Dictionary = {}


func remembering() -> bool:
	return not MouseMode.probe and DisplayServer.get_name() != "headless"


func _changed() -> void:
	if not _restoring and remembering():
		_save_in = 0.5


## A change made outside the controls, to be written.
func changed() -> void:
	_changed()


func save() -> void:
	_save_in = -1.0
	if not remembering():
		return
	var state := {"sliders": {}, "switches": {}, "choices": {}, "colours": {}, "extra": extra}
	for title: String in sliders:
		state["sliders"][title] = (sliders[title] as HSlider).value
	for title: String in switches:
		state["switches"][title] = (switches[title] as CheckButton).button_pressed
	for title: String in choices:
		for option: String in choices[title]:
			if (choices[title][option] as CheckBox).button_pressed:
				state["choices"][title] = option
	for title: String in pickers:
		state["colours"][title] = (pickers[title] as ColorPickerButton).color.to_html(false)
	var file := FileAccess.open(_state_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "\t"))


## Each setting put back through its own control, so everything that
## follows from it follows: choices, colours, switches, sliders. The
## extras are returned for the scene to apply.
func restore() -> Dictionary:
	if not remembering() or not FileAccess.file_exists(_state_path):
		return {}
	var file := FileAccess.open(_state_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var state: Dictionary = parsed
	_restoring = true
	var picked: Dictionary = state.get("choices", {})
	for title: String in picked:
		if choices.has(title) and (choices[title] as Dictionary).has(picked[title]):
			(choices[title][picked[title]] as CheckBox).button_pressed = true
	var colours: Dictionary = state.get("colours", {})
	for title: String in colours:
		if pickers.has(title):
			var picker := pickers[title] as ColorPickerButton
			picker.color = Color.html(str(colours[title]))
			picker.color_changed.emit(picker.color)
	var on: Dictionary = state.get("switches", {})
	for title: String in on:
		if switches.has(title):
			(switches[title] as CheckButton).button_pressed = bool(on[title])
	var values: Dictionary = state.get("sliders", {})
	for title: String in values:
		if sliders.has(title):
			(sliders[title] as HSlider).value = float(values[title])
	_restoring = false
	return state.get("extra", {})


func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE) and _save_in >= 0.0:
		save()
