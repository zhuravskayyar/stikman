extends Control

const GlyphText = preload("res://scripts/glyph_label.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.05, 0.05, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := Panel.new()
	var viewport_size := get_viewport_rect().size
	panel.size = Vector2(minf(420.0, viewport_size.x - 28.0), minf(250.0, viewport_size.y - 28.0))
	panel.position = (viewport_size - panel.size) * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e9dec4")
	style.border_color = Color("29231d")
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var heading := GlyphText.new()
	heading.text = "PAUSED"
	heading.font_size = 39.0
	heading.font_color = Color("a83a2d")
	heading.alignment = GlyphText.Align.CENTER
	heading.position = Vector2(20.0, 15.0)
	heading.size = Vector2(panel.size.x - 40.0, 54.0)
	panel.add_child(heading)
	var resume := _make_button("RESUME", Callable(self, "_resume"))
	resume.position = Vector2(25.0, 87.0)
	resume.size = Vector2(panel.size.x - 50.0, 55.0)
	panel.add_child(resume)
	var menu := _make_button("MAIN MENU", Callable(self, "_return_to_menu"))
	menu.position = Vector2(25.0, 157.0)
	menu.size = Vector2(panel.size.x - 50.0, 55.0)
	panel.add_child(menu)
	resume.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if InputManager.is_action_just_pressed("cancel"):
		_resume()
		get_viewport().set_input_as_handled()

func _make_button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d9ccb0")
	normal.border_color = Color("29231d")
	normal.set_border_width_all(2)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("a83a2d")
	hover.border_color = Color("29231d")
	hover.set_border_width_all(2)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("7d291f")
	pressed.border_color = Color("29231d")
	pressed.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	var label := GlyphText.new()
	label.text = caption
	label.font_size = 23.0
	label.font_color = Color("29231d")
	label.alignment = GlyphText.Align.CENTER
	label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.mouse_entered.connect(_on_button_hover.bind(label))
	button.mouse_exited.connect(_on_button_exit.bind(label))
	button.pressed.connect(_on_button_click)
	button.pressed.connect(action)
	return button

func _on_button_hover(label: GlyphText) -> void:
	label.font_color = Color("f4e9ce")
	Sfx.play_sfx(&"ui_click", -20.0, 1.3, 0.03)

func _on_button_exit(label: GlyphText) -> void:
	label.font_color = Color("29231d")

func _on_button_click() -> void:
	Sfx.play_sfx(&"ui_click", -10.0, 0.92, 0.04)

func _resume() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	queue_free()

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
