extends Control

const DEADZONE := 0.12
const JET_ACTIVATE := 0.42
const JET_RELEASE := 0.28
const PAPER_ATLAS: Texture2D = preload("res://assets/hud_tape_atlas.png")
const PAPER_REGION := Rect2(580, 467, 385, 359)

var _pointer_id := -1
var _origin := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _jet_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	InputManager.register_touch_target(self)
	InputManager.touch_pointer_ended.connect(_on_pointer_ended)

func _exit_tree() -> void:
	InputManager.unregister_touch_target(self)

func handle_touch_pressed(pointer_id: int, local_position: Vector2, _screen_position: Vector2) -> bool:
	if _pointer_id >= 0 or not Rect2(Vector2.ZERO, size).has_point(local_position):
		return false
	_pointer_id = pointer_id
	_origin = local_position
	_knob_offset = Vector2.ZERO
	_jet_active = false
	InputManager.set_touch_move_vector(pointer_id, Vector2.ZERO)
	InputManager.claim_touch_device()
	queue_redraw()
	return true

func handle_touch_moved(pointer_id: int, _local_position: Vector2, screen_position: Vector2) -> void:
	_on_pointer_moved(pointer_id, screen_position)

func _process(_delta: float) -> void:
	if _pointer_id >= 0:
		queue_redraw()

func _on_pointer_moved(pointer_id: int, screen_position: Vector2) -> void:
	if pointer_id != _pointer_id:
		return
	var local_position := get_global_transform_with_canvas().affine_inverse() * screen_position
	var radius := minf(size.x, size.y) * 0.38
	var raw_offset := local_position - _origin
	_knob_offset = raw_offset.limit_length(radius)

	var x_ratio := clampf(raw_offset.x / maxf(radius, 1.0), -1.0, 1.0)
	var x_amount := absf(x_ratio)
	var output_x := 0.0
	if x_amount > DEADZONE:
		var strength := (x_amount - DEADZONE) / (1.0 - DEADZONE)
		output_x = signf(x_ratio) * strength
	InputManager.set_touch_move_vector(pointer_id, Vector2(output_x, 0.0))

	var y_ratio := clampf(raw_offset.y / maxf(radius, 1.0), -1.0, 1.0)
	var jet_source := "touch:%d:move-jet" % pointer_id
	if not _jet_active and y_ratio <= -JET_ACTIVATE:
		InputManager.press_action("jump", jet_source)
		_jet_active = true
	elif _jet_active and y_ratio >= -JET_RELEASE:
		InputManager.release_action("jump", jet_source)
		_jet_active = false
	queue_redraw()

func _on_pointer_ended(pointer_id: int) -> void:
	if pointer_id != _pointer_id:
		return
	if _jet_active:
		InputManager.release_action("jump", "touch:%d:move-jet" % pointer_id)
		_jet_active = false
	InputManager.clear_touch_move_vector(pointer_id)
	_pointer_id = -1
	_knob_offset = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.38
	var center := _origin if _pointer_id >= 0 else size * 0.5
	var frame_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	draw_circle(center, radius * 0.9, Color("f3ead1b8"))
	draw_texture_rect_region(PAPER_ATLAS, frame_rect, PAPER_REGION)
	var knob_center := center + _knob_offset
	var knob_radius := radius * 0.37
	draw_circle(knob_center + Vector2(1.0, 2.0), knob_radius, Color("29233135"))
	draw_circle(knob_center, knob_radius, Color("e2d2b4e8"))
	draw_arc(knob_center, knob_radius, 0.0, TAU, 36, Color("292331d8"), 1.8, true)
	var hatch_offsets: Array[Vector2] = [Vector2(-0.27, -0.2), Vector2(-0.08, -0.31), Vector2(0.14, -0.22)]
	for offset in hatch_offsets:
		var start: Vector2 = knob_center + offset * knob_radius
		draw_line(start, start + Vector2(7.0, -5.0), Color("29233188"), 1.0, true)
