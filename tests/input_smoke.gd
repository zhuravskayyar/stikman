extends SceneTree

const CORE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down", "jump", "primary_action",
	"secondary_action", "skill_1", "skill_2", "skill_3", "skill_4", "interact", "cancel", "pause"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var input = root.get_node("InputManager")
	input.force_touch_hud = true
	input.reset_all_inputs()
	for action in CORE_ACTIONS:
		if not InputMap.has_action(action):
			_fail("Missing action: " + action)
			return
	if not _has_key("move_left", KEY_A) or not _has_key("move_left", KEY_LEFT) or not _has_key("jump", KEY_SPACE):
		_fail("Keyboard default bindings are incomplete")
		return
	if not _has_key("skill_1", KEY_Q) or not _has_key("skill_2", KEY_R) or not _has_key("skill_3", KEY_T) or not _has_key("skill_4", KEY_F):
		_fail("Skill keyboard bindings do not match Q/R/T/F")
		return
	if not _has_joy_button("jump", JOY_BUTTON_A) or not _has_joy_button("primary_action", JOY_BUTTON_X):
		_fail("Controller default bindings are incomplete")
		return
	Input.action_press("move_right")
	if not input.is_action_pressed("move_right"):
		_fail("A mapped action did not reach move_right")
		return
	Input.action_release("move_right")
	if input.is_action_pressed("move_right"):
		_fail("Action release left movement held")
		return
	input.press_action("skill_1", "test:edge")
	if not input.is_action_just_pressed("skill_1"):
		_fail("Action press edge was not reported")
		return
	input.release_action("skill_1", "test:edge")
	if not input.is_action_just_released("skill_1"):
		_fail("Action release edge was not reported")
		return

	input.press_action("move_right", "test:right")
	input.press_action("move_up", "test:up")
	var diagonal: Vector2 = input.get_move_vector()
	if not is_equal_approx(diagonal.length(), 1.0) or not is_equal_approx(diagonal.x, 0.7071067):
		_fail("Combined movement is not normalized: " + str(diagonal))
		return
	input.release_action("move_right", "test:right")
	input.release_action("move_up", "test:up")

	input.press_action("primary_action", "touch:11:primary_action")
	input.press_action("skill_1", "touch:12:skill_1")
	input.press_action("skill_2", "touch:13:skill_2")
	input.press_action("skill_3", "touch:14:skill_3")
	input.set_touch_move_vector(10, Vector2(0.8, 0.0))
	if not input.is_action_pressed("primary_action") or not input.is_action_pressed("skill_1") or not input.is_action_pressed("skill_2") or not input.is_action_pressed("skill_3"):
		_fail("Concurrent touch action sources did not stay pressed")
		return
	input._end_touch(11)
	if input.is_action_pressed("primary_action") or not input.is_action_pressed("skill_1") or input.get_touch_move_vector().x <= 0.7:
		_fail("Ending one pointer disturbed another touch or the joystick")
		return
	input._end_touch(12)
	input._end_touch(13)
	input._end_touch(14)
	input._end_touch(10)
	if input.get_touch_move_vector() != Vector2.ZERO:
		_fail("Touch movement stayed active after pointer end")
		return
	input.press_action("jump", "test:focus-held")
	input.set_touch_move_vector(22, Vector2.RIGHT)
	input.reset_all_inputs()
	if input.is_action_pressed("jump") or input.get_move_vector() != Vector2.ZERO or input.get_active_touch_count() != 0:
		_fail("Focus reset left a stuck input")
		return

	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var touch_hud: Control = arena.hud.touch_hud
	if not touch_hud.visible:
		_fail("Forced touch HUD did not appear")
		return
	var fire_button: Control = touch_hud.action_buttons["primary_action"]
	var skill_button: Control = touch_hud.action_buttons["skill_1"]
	var joystick: Control = touch_hud.joystick
	_send_touch(fire_button.get_global_rect().get_center(), 31, true)
	_send_touch(skill_button.get_global_rect().get_center(), 32, true)
	var joystick_center := joystick.get_global_rect().get_center()
	_send_touch(joystick_center, 33, true)
	_send_drag(joystick_center + Vector2(joystick.size.x * 0.34, 0.0), 33)
	await process_frame
	if not input.is_action_pressed("primary_action") or not input.is_action_pressed("skill_1") or input.get_touch_move_vector().x < 0.5:
		_fail("Touch HUD did not support joystick plus two simultaneous actions")
		return
	_send_touch(joystick_center, 34, true)
	_send_touch(Vector2.ZERO, 34, false)
	if input.get_touch_move_vector().x < 0.5:
		_fail("A second joystick pointer stole or cleared the active stick")
		return
	_send_touch(Vector2.ZERO, 31, false)
	if input.is_action_pressed("primary_action") or not input.is_action_pressed("skill_1"):
		_fail("Releasing one action pointer affected another action")
		return
	_send_touch(Vector2.ZERO, 32, false)
	_send_touch(Vector2.ZERO, 33, false)
	if input.get_touch_move_vector() != Vector2.ZERO:
		_fail("Touch cancel/release did not clear the joystick")
		return

	var original_window_size: Vector2i = root.size
	root.size = Vector2i(844, 390)
	await process_frame
	if touch_hud.get_viewport_rect().size.x <= touch_hud.get_viewport_rect().size.y:
		_fail("HUD did not observe the landscape resize")
		return
	for button in touch_hud.action_buttons.values():
		if minf(button.size.x, button.size.y) < 48.0:
			_fail("A touch target shrank below 48 viewport pixels")
			return
		var bounds := Rect2(Vector2.ZERO, touch_hud.get_viewport_rect().size)
		var rect: Rect2 = button.get_global_rect()
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > bounds.size.x or rect.end.y > bounds.size.y:
			_fail("A touch control moved outside the resized viewport")
			return
	root.size = Vector2i(390, 844)
	await process_frame
	if touch_hud.get_viewport_rect().size.y <= touch_hud.get_viewport_rect().size.x or not arena.orientation_hint.visible:
		_fail("Portrait orientation did not show the rotate hint")
		return
	root.size = original_window_size
	await process_frame

	var world_center := Vector2(root.size) * 0.5
	_send_mouse(world_center, true)
	if not input.is_action_pressed("primary_action"):
		_fail("An unconsumed gameplay click did not become primary_action")
		return
	input.reset_all_inputs()
	if input.is_action_pressed("primary_action"):
		_fail("Focus reset left a mouse action stuck")
		return
	_send_mouse(world_center, false)
	var zoom_center: Vector2 = arena.hud.zoom_button.get_global_rect().get_center()
	_send_mouse(zoom_center, true)
	_send_mouse(zoom_center, false)
	if input.is_action_pressed("primary_action"):
		_fail("A click consumed by the HUD reached gameplay as primary_action")
		return
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.position = Vector2(400.0, 400.0)
	emulated_mouse.global_position = emulated_mouse.position
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(emulated_mouse, true)
	if input.is_action_pressed("primary_action"):
		_fail("A touch-generated mouse event duplicated gameplay primary_action")
		return
	emulated_mouse.pressed = false
	root.push_input(emulated_mouse, true)
	print("INPUT PASS: actions, keyboard/gamepad bindings, normalized movement, independent multitouch, focus reset, touch HUD, UI click consumption")
	input.force_touch_hud = false
	input.reset_all_inputs()
	quit(0)

func _has_key(action: String, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.keycode == key or event.physical_keycode == key):
			return true
	return false

func _has_joy_button(action: String, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _send_touch(position: Vector2, pointer_id: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = pointer_id
	event.pressed = pressed
	root.push_input(event, true)

func _send_drag(position: Vector2, pointer_id: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.index = pointer_id
	root.push_input(event, true)

func _send_mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _fail(message: String) -> void:
	push_error("INPUT FAIL: " + message)
	quit(1)
