extends Node

signal active_input_device_changed(device: String)
signal touch_pointer_moved(pointer_id: int, screen_position: Vector2)
signal touch_pointer_ended(pointer_id: int)
signal zoom_requested(factor: float)
signal gamepad_connection_changed(connected: bool)

const INPUT_DEADZONE := 0.18
const TOUCH_DEADZONE := 0.16
const CORE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down", "jump",
	"primary_action", "secondary_action", "skill_1", "skill_2", "skill_3",
	"skill_4", "interact", "cancel", "pause"
]
const EXTRA_ACTIONS := [
	"weapon_next", "weapon_1", "weapon_2", "weapon_3", "weapon_4",
	"weapon_5", "weapon_6", "weapon_7", "weapon_8", "zoom_in", "zoom_out", "zoom_cycle",
	"zoom_reset", "debug_level", "debug_input"
]

var _manual_sources: Dictionary = {}
var _manual_press_frames: Dictionary = {}
var _manual_release_frames: Dictionary = {}
var _touch_move_vectors: Dictionary = {}
var _touch_aim_vectors: Dictionary = {}
var _active_touches: Dictionary = {}
var _touch_owners: Dictionary = {}
var _touch_targets: Array[Control] = []
var _last_input_device := "keyboard"
var _gamepad_connected := false
var force_touch_hud := false
var _web_visibility_callback: JavaScriptObject
var _web_document: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_actions()
	_gamepad_connected = not Input.get_connected_joypads().is_empty()
	if is_touch_capable():
		_last_input_device = "touch"
	get_tree().root.focus_exited.connect(_on_focus_lost)
	get_tree().root.focus_entered.connect(_on_focus_gained)
	if OS.has_feature("web"):
		_web_document = JavaScriptBridge.get_interface("document")
		_web_visibility_callback = JavaScriptBridge.create_callback(_on_browser_visibility_changed)
		_web_document.addEventListener("visibilitychange", _web_visibility_callback)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_set_last_device("keyboard")
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_last_device("mouse")
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_last_device("gamepad")
	elif event is InputEventScreenTouch:
		_set_last_device("touch")
		if event.pressed:
			_active_touches[event.index] = event.position
			var target := _find_touch_target(event.position)
			if target != null and target.has_method("handle_touch_pressed"):
				var local_position: Vector2 = target.get_global_transform_with_canvas().affine_inverse() * event.position
				if bool(target.call("handle_touch_pressed", event.index, local_position, event.position)):
					_touch_owners[event.index] = target
					get_viewport().set_input_as_handled()
		else:
			var was_captured := _touch_owners.has(event.index)
			_end_touch(event.index)
			if was_captured:
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_set_last_device("touch")
		_active_touches[event.index] = event.position
		touch_pointer_moved.emit(event.index, event.position)
		if _touch_owners.has(event.index):
			var target: Control = _touch_owners[event.index]
			if is_instance_valid(target) and target.has_method("handle_touch_moved"):
				var local_position: Vector2 = target.get_global_transform_with_canvas().affine_inverse() * event.position
				target.call("handle_touch_moved", event.index, local_position, event.position)
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		_release_mouse_action(event.button_index)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				press_action("primary_action", "mouse:left")
			MOUSE_BUTTON_RIGHT:
				press_action("secondary_action", "mouse:right")
			MOUSE_BUTTON_WHEEL_UP:
				zoom_requested.emit(1.12)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_requested.emit(1.0 / 1.12)
				get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		zoom_requested.emit(event.factor)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var connected := not Input.get_connected_joypads().is_empty()
	if connected != _gamepad_connected:
		_gamepad_connected = connected
		gamepad_connection_changed.emit(connected)

func _setup_actions() -> void:
	for action in CORE_ACTIONS + EXTRA_ACTIONS + ["reload", "throw_grenade"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, INPUT_DEADZONE)

	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("jump", [KEY_SPACE, KEY_W])
	_bind_keys("interact", [KEY_E])
	_bind_keys("cancel", [KEY_ESCAPE])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("skill_1", [KEY_Q])
	_bind_keys("skill_2", [KEY_R])
	_bind_keys("skill_3", [KEY_T])
	_bind_keys("skill_4", [KEY_F, KEY_G])
	_bind_keys("reload", [KEY_R])
	_bind_keys("throw_grenade", [KEY_G])
	_bind_keys("weapon_next", [KEY_T])
	_bind_keys("weapon_1", [KEY_1])
	_bind_keys("weapon_2", [KEY_2])
	_bind_keys("weapon_3", [KEY_3])
	_bind_keys("weapon_4", [KEY_4])
	_bind_keys("weapon_5", [KEY_5])
	_bind_keys("weapon_6", [KEY_6])
	_bind_keys("weapon_7", [KEY_7])
	_bind_keys("weapon_8", [KEY_8])
	_bind_keys("zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_bind_keys("zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	_bind_keys("zoom_reset", [KEY_0])
	_bind_keys("debug_level", [KEY_F3])
	_bind_keys("debug_input", [KEY_F2])

	_bind_joy_buttons("jump", [JOY_BUTTON_A])
	_bind_joy_buttons("primary_action", [JOY_BUTTON_X])
	_bind_joy_buttons("secondary_action", [JOY_BUTTON_B])
	_bind_joy_buttons("interact", [JOY_BUTTON_Y])
	_bind_joy_buttons("cancel", [JOY_BUTTON_B, JOY_BUTTON_BACK])
	_bind_joy_buttons("pause", [JOY_BUTTON_START])
	_bind_joy_buttons("skill_1", [JOY_BUTTON_LEFT_STICK])
	_bind_joy_buttons("skill_2", [JOY_BUTTON_LEFT_SHOULDER])
	_bind_joy_buttons("skill_3", [JOY_BUTTON_RIGHT_SHOULDER])
	_bind_joy_buttons("skill_4", [JOY_BUTTON_RIGHT_STICK])
	_bind_joy_buttons("weapon_next", [JOY_BUTTON_RIGHT_SHOULDER])
	_bind_joy_buttons("reload", [JOY_BUTTON_LEFT_SHOULDER])
func _bind_keys(action: String, keys: Array[int]) -> void:
	for key in keys:
		var found := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey and (existing.physical_keycode == key or existing.keycode == key):
				found = true
				break
		if not found:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _bind_joy_buttons(action: String, buttons: Array[int]) -> void:
	for button in buttons:
		var found := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEventJoypadButton and existing.button_index == button:
				found = true
				break
		if not found:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)

func press_action(action: String, source_id: String) -> void:
	if not _manual_sources.has(action):
		_manual_sources[action] = {}
	var sources: Dictionary = _manual_sources[action]
	if sources.has(source_id):
		return
	var was_pressed := is_action_pressed(action)
	sources[source_id] = true
	_manual_sources[action] = sources
	if not was_pressed:
		_manual_press_frames[action] = Engine.get_process_frames()

func release_action(action: String, source_id: String) -> void:
	if not _manual_sources.has(action):
		return
	var sources: Dictionary = _manual_sources[action]
	if not sources.has(source_id):
		return
	sources.erase(source_id)
	_manual_sources[action] = sources
	if sources.is_empty() and not Input.is_action_pressed(action):
		_manual_release_frames[action] = Engine.get_process_frames()

func pulse_action(action: String, source_id: String = "ui:pulse") -> void:
	press_action(action, source_id)
	release_action(action, source_id)

func is_action_pressed(action: String) -> bool:
	var sources: Dictionary = _manual_sources.get(action, {})
	return Input.is_action_pressed(action) or not sources.is_empty()

func is_action_just_pressed(action: String) -> bool:
	if int(_manual_press_frames.get(action, -1)) == Engine.get_process_frames():
		return true
	if not _manual_sources.get(action, {}).is_empty():
		return false
	return Input.is_action_just_pressed(action)

func is_action_just_released(action: String) -> bool:
	if is_action_pressed(action):
		return false
	return Input.is_action_just_released(action) or int(_manual_release_frames.get(action, -1)) == Engine.get_process_frames()

func get_move_vector() -> Vector2:
	var direction := Vector2(
		float(is_action_pressed("move_right")) - float(is_action_pressed("move_left")),
		float(is_action_pressed("move_down")) - float(is_action_pressed("move_up"))
	)
	var joystick := _get_gamepad_vector()
	for value in _touch_move_vectors.values():
		if value is Vector2:
			joystick += value
	var combined := direction + joystick
	return combined.limit_length(1.0)

func set_touch_move_vector(pointer_id: int, value: Vector2) -> void:
	_touch_move_vectors[pointer_id] = value.limit_length(1.0)

func clear_touch_move_vector(pointer_id: int) -> void:
	_touch_move_vectors.erase(pointer_id)

func set_touch_aim_vector(pointer_id: int, value: Vector2) -> void:
	_touch_aim_vectors[pointer_id] = value.normalized() if value.is_finite() else Vector2.ZERO

func clear_touch_aim_vector(pointer_id: int) -> void:
	_touch_aim_vectors.erase(pointer_id)

func get_active_touch_count() -> int:
	return _active_touches.size()

func get_active_touch_positions() -> Dictionary:
	return _active_touches.duplicate()

func get_touch_move_vector() -> Vector2:
	var result := Vector2.ZERO
	for value in _touch_move_vectors.values():
		if value is Vector2:
			result += value
	return result.limit_length(1.0)

func get_display_scale() -> float:
	if OS.has_feature("web"):
		return float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true))
	return DisplayServer.screen_get_scale()

func get_css_viewport_size(viewport_size: Vector2) -> Vector2:
	if OS.has_feature("web"):
		var browser_size := Vector2(
			float(JavaScriptBridge.eval("window.innerWidth", true)),
			float(JavaScriptBridge.eval("window.innerHeight", true))
		)
		if browser_size.x > 0.0 and browser_size.y > 0.0:
			return browser_size
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x < 160.0 or window_size.y < 160.0:
		return viewport_size
	return window_size / maxf(get_display_scale(), 1.0)

func get_viewport_units_per_css_pixel(viewport_size: Vector2) -> float:
	var css_size := get_css_viewport_size(viewport_size)
	if css_size.x <= 0.0 or css_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / css_size.x, viewport_size.y / css_size.y)

func get_active_input_device() -> String:
	return _last_input_device

func register_touch_target(target: Control) -> void:
	if not _touch_targets.has(target):
		_touch_targets.append(target)

func unregister_touch_target(target: Control) -> void:
	_touch_targets.erase(target)
	for pointer_id in _touch_owners.keys():
		if _touch_owners[pointer_id] == target:
			_end_touch(int(pointer_id))

func claim_touch_device() -> void:
	_set_last_device("touch")

func has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()

func is_touch_capable() -> bool:
	if force_touch_hud:
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(window.matchMedia && window.matchMedia('(pointer: coarse)').matches) || (navigator.maxTouchPoints > 0)", true))
	return DisplayServer.is_touchscreen_available()

func get_safe_area_insets(viewport_size: Vector2) -> Vector4:
	if not is_touch_capable():
		return Vector4.ZERO
	if OS.has_feature("web"):
		var css_insets = JavaScriptBridge.eval("""(() => {
			const probe = document.createElement('div');
			probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
			document.body.appendChild(probe);
			const style = getComputedStyle(probe);
			const insets = [style.paddingLeft, style.paddingTop, style.paddingRight, style.paddingBottom].map(value => parseFloat(value) || 0);
			probe.remove();
			return insets.join(',');
		})()""", true)
		var inset_values := str(css_insets).split(",")
		if inset_values.size() == 4:
			var insets := Vector4(
				float(inset_values[0]),
				float(inset_values[1]),
				float(inset_values[2]),
				float(inset_values[3])
			)
			return insets * get_viewport_units_per_css_pixel(viewport_size)
		return Vector4.ZERO
	var safe_area := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	if safe_area.size == Vector2i.ZERO or window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var window_position := DisplayServer.window_get_position()
	var safe_in_window := Rect2i(safe_area.position - window_position, safe_area.size).intersection(Rect2i(Vector2i.ZERO, window_size))
	if safe_in_window.size == Vector2i.ZERO:
		return Vector4.ZERO
	var scale := viewport_size / Vector2(window_size)
	return Vector4(
		float(safe_in_window.position.x) * scale.x,
		float(safe_in_window.position.y) * scale.y,
		float(window_size.x - safe_in_window.end.x) * scale.x,
		float(window_size.y - safe_in_window.end.y) * scale.y
	)

func get_gamepad_vector() -> Vector2:
	return _get_gamepad_vector()

func get_aim_vector(origin_world: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if not stick.is_finite():
			continue
		var strength := stick.length()
		if strength <= INPUT_DEADZONE:
			continue
		var scaled_strength := minf(1.0, (strength - INPUT_DEADZONE) / (1.0 - INPUT_DEADZONE))
		result += stick.normalized() * scaled_strength
	if result.length_squared() > 0.0:
		return result.limit_length(1.0)
	for value in _touch_aim_vectors.values():
		if value is Vector2 and value.length_squared() > 0.0:
			return value
	if _last_input_device == "mouse":
		var mouse_world := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
		var mouse_delta := mouse_world - origin_world
		if mouse_delta.is_finite():
			return mouse_delta
	return Vector2.ZERO

func _get_gamepad_vector() -> Vector2:
	var result := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if not stick.is_finite():
			continue
		var strength := stick.length()
		if strength <= INPUT_DEADZONE:
			continue
		var scaled_strength := minf(1.0, (strength - INPUT_DEADZONE) / (1.0 - INPUT_DEADZONE))
		result += stick.normalized() * scaled_strength
	return result.limit_length(1.0)

func _set_last_device(device: String) -> void:
	if _last_input_device == device:
		return
	_last_input_device = device
	active_input_device_changed.emit(device)

func _find_touch_target(screen_position: Vector2) -> Control:
	for index in range(_touch_targets.size() - 1, -1, -1):
		var target := _touch_targets[index]
		if is_instance_valid(target) and target.is_visible_in_tree() and target.get_global_rect().has_point(screen_position):
			return target
	return null

func _release_mouse_action(button: int) -> void:
	match button:
		MOUSE_BUTTON_LEFT:
			release_action("primary_action", "mouse:left")
		MOUSE_BUTTON_RIGHT:
			release_action("secondary_action", "mouse:right")

func _end_touch(pointer_id: int) -> void:
	_active_touches.erase(pointer_id)
	_touch_move_vectors.erase(pointer_id)
	_touch_aim_vectors.erase(pointer_id)
	_touch_owners.erase(pointer_id)
	var prefix := "touch:%d:" % pointer_id
	for action in _manual_sources.keys():
		var sources: Dictionary = _manual_sources[action]
		for source_id in sources.keys():
			if str(source_id).begins_with(prefix):
				release_action(str(action), str(source_id))
	touch_pointer_ended.emit(pointer_id)

func _on_focus_lost() -> void:
	reset_all_inputs()

func _on_focus_gained() -> void:
	reset_all_inputs()

func _on_browser_visibility_changed(_args: Array) -> void:
	if bool(JavaScriptBridge.eval("document.visibilityState === 'hidden'", true)):
		reset_all_inputs()

func reset_all_inputs() -> void:
	for action in _manual_sources.keys():
		for source_id in _manual_sources[action].keys():
			release_action(str(action), str(source_id))
	_manual_sources.clear()
	_touch_move_vectors.clear()
	_touch_aim_vectors.clear()
	for pointer_id in _active_touches.keys():
		touch_pointer_ended.emit(int(pointer_id))
	_active_touches.clear()
	_touch_owners.clear()
	for action in CORE_ACTIONS + EXTRA_ACTIONS + ["reload", "throw_grenade"]:
		Input.action_release(action)
	_manual_press_frames.clear()
	_manual_release_frames.clear()
