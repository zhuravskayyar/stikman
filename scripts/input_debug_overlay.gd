extends Control

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "primary_action", "secondary_action", "skill_1", "skill_2", "skill_3", "skill_4", "interact", "cancel", "pause"]

func _ready() -> void:
	position = Vector2(12.0, 12.0)
	size = Vector2(372.0, 291.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var move := InputManager.get_move_vector()
	var gamepad_vector := InputManager.get_gamepad_vector()
	var active_actions: Array[String] = []
	for action in ACTIONS:
		if InputManager.is_action_pressed(action):
			active_actions.append(action)
	var gamepads := Input.get_connected_joypads()
	var gamepad_name := "disconnected"
	if not gamepads.is_empty():
		gamepad_name = Input.get_joy_name(gamepads[0])
	var orientation := "landscape" if viewport_size.x >= viewport_size.y else "portrait"
	var screen_scale := InputManager.get_display_scale()
	var lines := [
		"Input device: %s" % InputManager.get_active_input_device(),
		"Move: %.2f / %.2f" % [move.x, move.y],
		"Active touches: %d" % InputManager.get_active_touch_count(),
		"Pressed: %s" % (", ".join(active_actions) if not active_actions.is_empty() else "none"),
		"Touch joystick: %.2f / %.2f" % [InputManager.get_touch_move_vector().x, InputManager.get_touch_move_vector().y],
		"Touch sources: %s" % str(InputManager._touch_move_vectors),
		"Gamepad stick: %.2f / %.2f" % [gamepad_vector.x, gamepad_vector.y],
		"Gamepad: %s" % gamepad_name,
		"Viewport: %d x %d" % [roundi(viewport_size.x), roundi(viewport_size.y)],
		"devicePixelRatio: %.2f" % screen_scale,
		"Orientation: %s" % orientation
	]
	draw_rect(Rect2(Vector2.ZERO, size), Color("171620e8"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("f3ead1"), false, 2.0)
	var y := 24.0
	for line in lines:
		draw_string(ThemeDB.fallback_font, Vector2(12.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 14, Color("fff4dc"))
		y += 23.0
