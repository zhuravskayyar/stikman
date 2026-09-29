extends CanvasLayer

const GlyphText = preload("res://scripts/glyph_label.gd")

var hint_label: Control

func _ready() -> void:
	layer = 100
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	hint_label = GlyphText.new()
	hint_label.text = "ПОВЕРНІТЬ ПРИСТРІЙ ГОРИЗОНТАЛЬНО"
	hint_label.font_size = 24.0
	hint_label.font_color = Color("fff4dc")
	hint_label.alignment = GlyphText.Align.CENTER
	hint_label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(hint_label)
	get_viewport().size_changed.connect(_layout)
	InputManager.active_input_device_changed.connect(_on_input_device_changed)
	_layout()

func _on_input_device_changed(_device: String) -> void:
	_layout()

func _layout() -> void:
	if not is_instance_valid(hint_label):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	visible = not OS.has_feature("web") and InputManager.is_touch_capable() and viewport_size.y > viewport_size.x * 1.12
	var units_per_css_pixel := InputManager.get_viewport_units_per_css_pixel(viewport_size)
	hint_label.font_size = clampf(minf(viewport_size.x, viewport_size.y) * 0.055, 20.0 * units_per_css_pixel, 32.0 * units_per_css_pixel)
	hint_label.position = Vector2(viewport_size.x * 0.08, viewport_size.y * 0.42)
	hint_label.size = Vector2(viewport_size.x * 0.84, viewport_size.y * 0.16)
