extends Control

const GlyphText = preload("res://scripts/glyph_label.gd")

var entries: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_entries)
	z_index = 20

func show_player_kill(killer: String, victim: String) -> void:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.84)
	style.border_color = Color("a83a2d")
	style.border_width_left = 3
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)
	var label := GlyphText.new()
	label.text = killer.to_upper() + "  >  " + victim.to_upper()
	label.font_size = 17.0
	label.font_color = Color("f3e8cf")
	label.alignment = GlyphText.Align.RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(label)
	add_child(card)
	entries.append(card)
	while entries.size() > 4:
		var oldest: Control = entries.pop_front()
		oldest.queue_free()
	_layout_entries()
	_expire_later(card)

func _expire_later(card: Control) -> void:
	await get_tree().create_timer(4.2).timeout
	if is_instance_valid(card):
		entries.erase(card)
		card.queue_free()
		_layout_entries()

func _layout_entries() -> void:
	for index in range(entries.size()):
		var card := entries[index]
		card.size = Vector2(330.0, 32.0)
		card.position = Vector2(size.x - 350.0, 58.0 + index * 39.0)
