extends Control

const DEADZONE := 0.12

var _pointer_id := -1
var _aim_marker := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	InputManager.register_touch_target(self)
	InputManager.touch_pointer_ended.connect(_on_pointer_ended)

func _exit_tree() -> void:
	InputManager.unregister_touch_target(self)

func handle_touch_pressed(pointer_id: int, local_position: Vector2, screen_position: Vector2) -> bool:
	if _pointer_id >= 0 or not Rect2(Vector2.ZERO, size).has_point(local_position):
		return false
	_pointer_id = pointer_id
	_aim_marker = local_position
	_update_aim(screen_position)
	InputManager.press_action("primary_action", "touch:%d:aim-fire" % pointer_id)
	InputManager.claim_touch_device()
	queue_redraw()
	return true

func handle_touch_moved(pointer_id: int, local_position: Vector2, screen_position: Vector2) -> void:
	if pointer_id != _pointer_id:
		return
	_aim_marker = local_position
	_update_aim(screen_position)
	queue_redraw()

func _update_aim(screen_position: Vector2) -> void:
	var viewport_center := get_viewport_rect().size * 0.5
	var direction := screen_position - viewport_center
	if direction.length() < minf(size.x, size.y) * DEADZONE:
		InputManager.set_touch_aim_vector(_pointer_id, Vector2.ZERO)
	else:
		InputManager.set_touch_aim_vector(_pointer_id, direction.normalized())

func _draw() -> void:
	if _pointer_id < 0:
		return
	var radius := 17.0
	draw_circle(_aim_marker, radius, Color("f3ead1b8"))
	draw_arc(_aim_marker, radius, 0.0, TAU, 32, Color("292331d8"), 1.8, true)
	var ink := Color("292331")
	draw_line(_aim_marker + Vector2(-radius - 5.0, 0.0), _aim_marker + Vector2(-radius * 0.45, 0.0), ink, 1.5, true)
	draw_line(_aim_marker + Vector2(radius * 0.45, 0.0), _aim_marker + Vector2(radius + 5.0, 0.0), ink, 1.5, true)
	draw_line(_aim_marker + Vector2(0.0, -radius - 5.0), _aim_marker + Vector2(0.0, -radius * 0.45), ink, 1.5, true)
	draw_line(_aim_marker + Vector2(0.0, radius * 0.45), _aim_marker + Vector2(0.0, radius + 5.0), ink, 1.5, true)
	draw_circle(_aim_marker, 2.5, ink)

func _on_pointer_ended(pointer_id: int) -> void:
	if pointer_id != _pointer_id:
		return
	InputManager.clear_touch_aim_vector(pointer_id)
	_pointer_id = -1
	queue_redraw()
