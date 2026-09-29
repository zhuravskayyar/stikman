extends Control

const PAPER_ATLAS: Texture2D = preload("res://assets/hud_tape_atlas.png")
const GRENADE_REGION := Rect2(580, 467, 385, 359)

var action_name := ""
var icon_texture: Texture2D
var paper_region := GRENADE_REGION
var mark := ""
var hold_action := false
var counter_text := ""
var action_enabled := true
var _pointer_ids: Dictionary = {}

func configure(action: String, icon: Texture2D, frame: Rect2, button_mark := "", held := false) -> void:
	action_name = action
	icon_texture = icon
	paper_region = frame
	mark = button_mark
	hold_action = held
	queue_redraw()

func set_counter(value: String) -> void:
	if counter_text == value:
		return
	counter_text = value
	queue_redraw()

func set_action_enabled(value: bool) -> void:
	if action_enabled == value:
		return
	action_enabled = value
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(48.0, 48.0)
	InputManager.register_touch_target(self)
	InputManager.touch_pointer_ended.connect(_on_pointer_ended)

func _exit_tree() -> void:
	InputManager.unregister_touch_target(self)

func handle_touch_pressed(pointer_id: int, local_position: Vector2, _screen_position: Vector2) -> bool:
	if not action_enabled or not Rect2(Vector2.ZERO, size).has_point(local_position):
		return false
	_pointer_ids[pointer_id] = true
	var source_id := "touch:%d:%s" % [pointer_id, action_name]
	if hold_action:
		InputManager.press_action(action_name, source_id)
	else:
		InputManager.pulse_action(action_name, source_id)
	InputManager.claim_touch_device()
	queue_redraw()
	return true

func handle_touch_moved(_pointer_id: int, _local_position: Vector2, _screen_position: Vector2) -> void:
	pass

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	var pressed := not _pointer_ids.is_empty()
	var paper := Color("e8dac0") if pressed else Color("f3ead1")
	if not action_enabled:
		paper.a = 0.62
	draw_circle(center, radius * 0.78, paper)
	draw_texture_rect_region(PAPER_ATLAS, Rect2(Vector2.ZERO, size), paper_region)
	if icon_texture != null:
		var icon_side := radius * 1.04
		var icon_rect := Rect2(center - Vector2.ONE * icon_side * 0.5, Vector2.ONE * icon_side)
		draw_texture_rect(icon_texture, icon_rect, false, Color("292331" if action_enabled else "756b60"))
	elif mark == "pause":
		var bar_width := maxf(3.0, radius * 0.13)
		var bar_height := radius * 0.75
		draw_rect(Rect2(center + Vector2(-radius * 0.29, -bar_height * 0.5), Vector2(bar_width, bar_height)), Color("292331"))
		draw_rect(Rect2(center + Vector2(radius * 0.16, -bar_height * 0.5), Vector2(bar_width, bar_height)), Color("292331"))
	elif mark == "interact":
		var ink := Color("292331")
		draw_line(center + Vector2(0.0, radius * 0.37), center - Vector2(0.0, radius * 0.2), ink, maxf(2.0, radius * 0.1), true)
		draw_line(center - Vector2(0.0, radius * 0.2), center + Vector2(-radius * 0.22, 0.02), ink, maxf(2.0, radius * 0.1), true)
		draw_line(center - Vector2(0.0, radius * 0.2), center + Vector2(radius * 0.22, 0.02), ink, maxf(2.0, radius * 0.1), true)
	if not counter_text.is_empty():
		var badge_center := center + Vector2(radius * 0.56, radius * 0.55)
		var badge_radius := radius * 0.22
		draw_circle(badge_center, badge_radius, Color("f3ead1"))
		draw_arc(badge_center, badge_radius, 0.0, TAU, 24, Color("292331"), maxf(1.0, radius * 0.035), true)
		var font_size := clampi(roundi(radius * 0.36), 11, 18)
		var text_width := ThemeDB.fallback_font.get_string_size(counter_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		draw_string(ThemeDB.fallback_font, badge_center + Vector2(-text_width * 0.5, font_size * 0.34), counter_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("292331"))

func _on_pointer_ended(pointer_id: int) -> void:
	if _pointer_ids.erase(pointer_id):
		queue_redraw()
