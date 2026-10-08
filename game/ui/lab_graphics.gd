class_name LabGraphics
extends Node
## The graphics options in a lab scene: the same settings the worlds
## keep (GraphicsSettings, in user://settings.json), so a choice made in
## a lab holds in the worlds and the other way round. A lab gets the
## parts that belong to the whole engine: the preset, render resolution
## and upscaler, anti-aliasing, the shadow map's size and softening, and
## VSync. What a lab's environment does (ambient occlusion, glow, global
## illumination, fog) stays on the lab's own panels.
##
## `attach` puts it in a lab with its controls in a panel column the lab
## supplies; F7 steps through the presets, with a line at the top of the
## screen saying what was chosen.

const NOTE_SIZE := 11

var settings := GraphicsSettings.new()
var _after: Callable
var _scale: HSlider
var _scale_label: Label
var _menus: Dictionary = {}             # key -> OptionButton
var _summary: Label
var _toast: Label
var _toast_left := 0.0
var _filling := false


## A LabGraphics in `lab`, its controls in `column`. `after` runs after
## each apply with the settings, for a lab that needs something on top
## (a softening floor).
static func attach(lab: Node, column: VBoxContainer, after: Callable = Callable()) -> LabGraphics:
	var g := LabGraphics.new()
	g.name = "LabGraphics"
	g._after = after
	lab.add_child(g)
	g._build(column)
	g.settings = GraphicsSettings.load_saved()
	g._fill()
	g._apply()
	return g


func _build(column: VBoxContainer) -> void:
	var presets := HBoxContainer.new()
	for preset: String in GraphicsSettings.PRESET_NAMES:
		var b := Button.new()
		b.text = preset
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			settings.set_preset(preset)
			_changed())
		presets.add_child(b)
	column.add_child(presets)
	_summary = _note(column, "")
	_note(column, "Shared with every world and lab; F7 steps through the presets. Low suits this laptop.")

	var row := HBoxContainer.new()
	_scale_label = Label.new()
	_scale_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(_scale_label)
	_scale = HSlider.new()
	_scale.focus_mode = Control.FOCUS_NONE
	_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale.min_value = 0.25
	_scale.max_value = 1.0
	_scale.step = 0.01
	_scale.value_changed.connect(func(v: float) -> void:
		_scale_label.text = "Resolution: %d%%" % roundi(v * 100.0)
		if not _filling:
			settings.values["scale"] = v
			_changed())
	row.add_child(_scale)
	column.add_child(row)
	_note(column, "The share of the window's width and height the 3D picture is drawn at before it is scaled up to fill it. Half draws a quarter of the pixels.")
	_menu(column, "upscaler", "How the smaller picture is scaled up. FSR 1 sharpens as it enlarges; FSR 2 also smooths edges over several frames, at a cost.")
	_menu(column, "aa", "Smoothing of jagged edges.")
	_menu(column, "shadow_size", "The size of the picture that holds the sun's shadows. Larger is sharper and costs more to draw.")
	_menu(column, "shadow_filter", "How much a shadow's edge is blurred, and how many samples that takes.")
	_menu(column, "vsync", "Whether a finished frame waits for the screen's next refresh.")


func _menu(column: VBoxContainer, key: String, text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = str(GraphicsSettings.LABELS[key])
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var menu := OptionButton.new()
	menu.focus_mode = Control.FOCUS_NONE
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair: Array in GraphicsSettings.CHOICES[key]:
		menu.add_item(str(pair[1]))
	menu.item_selected.connect(func(i: int) -> void:
		if not _filling:
			settings.values[key] = GraphicsSettings.CHOICES[key][i][0]
			_changed())
	row.add_child(menu)
	column.add_child(row)
	_menus[key] = menu
	_note(column, text)


func _note(column: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BenchPanel.COLUMN_W, 0)
	label.add_theme_font_size_override("font_size", NOTE_SIZE)
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	column.add_child(label)
	return label


## The controls set from the settings, without each reporting a change.
func _fill() -> void:
	_filling = true
	_scale.value = float(settings.values["scale"])
	_scale_label.text = "Resolution: %d%%" % roundi(float(settings.values["scale"]) * 100.0)
	for key: String in _menus:
		(_menus[key] as OptionButton).select(settings.choice_index(key))
	_summary.text = settings.summary()
	_filling = false


func _changed() -> void:
	_fill()
	_apply()
	settings.save_shared()


func _apply() -> void:
	settings.apply_engine(get_viewport())
	if _after.is_valid():
		_after.call(settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("graphics_preset"):
		settings.next_preset()
		_changed()
		_show_toast("Graphics: " + settings.summary())


func _show_toast(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_toast = Label.new()
		_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_toast.offset_top = 16.0
		_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.add_theme_font_size_override("font_size", 15)
		_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_toast.add_theme_constant_override("outline_size", 4)
		layer.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = 2.5


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)
