extends Control

const TouchButton = preload("res://scripts/touch_action_button.gd")
const VirtualJoystickScript = preload("res://scripts/virtual_joystick.gd")
const TouchAimAreaScript = preload("res://scripts/touch_aim_area.gd")
const GRENADE_ICON: Texture2D = preload("res://assets/hud_icon_grenade.png")
const JET_ICON: Texture2D = preload("res://assets/hud_icon_jet.png")
const PUNCH_ICON: Texture2D = preload("res://assets/hud_icon_punch.png")

const GRENADE_REGION := Rect2(580, 467, 385, 359)
const JET_REGION := Rect2(994, 462, 406, 376)
const PUNCH_REGION := Rect2(1396, 468, 360, 366)
const LEFT_JOYSTICK_SCALE := 1.5
const RIGHT_JOYSTICK_SCALE := 2.0

var joystick: Control
var aim_area: Control
var action_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick = VirtualJoystickScript.new()
	add_child(joystick)
	aim_area = TouchAimAreaScript.new()
	add_child(aim_area)
	_add_button("grenade", "skill_4", GRENADE_ICON, GRENADE_REGION)
	_add_button("jetpack", "jump", JET_ICON, JET_REGION, "", true)
	_add_button("punch", "skill_1", PUNCH_ICON, PUNCH_REGION, "", false, true)
	_add_button("interact", "interact", null, GRENADE_REGION, "interact")
	_add_button("pause", "pause", null, PUNCH_REGION, "pause")
	action_buttons["interact"].visible = false
	get_viewport().size_changed.connect(_layout)
	InputManager.active_input_device_changed.connect(_on_input_device_changed)
	_layout()
	_update_visibility()

func _add_button(key: String, action: String, icon: Texture2D, paper_region: Rect2, mark := "", held := false, directional := false) -> void:
	var button := TouchButton.new()
	button.configure(action, icon, paper_region, mark, held, directional)
	add_child(button)
	action_buttons[key] = button

func _on_input_device_changed(_device: String) -> void:
	_update_visibility()

func _update_visibility() -> void:
	visible = InputManager.is_touch_capable()

func set_interact_available(available: bool) -> void:
	if action_buttons.has("interact") and action_buttons["interact"].visible != available:
		action_buttons["interact"].visible = available

func set_grenades(count: int) -> void:
	if not action_buttons.has("grenade"):
		return
	var button: Control = action_buttons["grenade"]
	button.set_counter(str(count))
	button.set_action_enabled(count > 0)

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or not is_instance_valid(joystick):
		return
	var safe := InputManager.get_safe_area_insets(viewport_size)
	var css_size := InputManager.get_css_viewport_size(viewport_size)
	var units_per_css_pixel := InputManager.get_viewport_units_per_css_pixel(viewport_size)
	var side_css := clampf(minf(css_size.y * 0.18, css_size.x * 0.105), 46.0, 72.0)
	var side := side_css * units_per_css_pixel
	var gap := maxf(8.0 * units_per_css_pixel, side * 0.16)
	var left_pad := maxf(14.0 * units_per_css_pixel, safe.x + 10.0 * units_per_css_pixel)
	var right_pad := maxf(14.0 * units_per_css_pixel, safe.z + 10.0 * units_per_css_pixel)
	var top_pad := maxf(12.0 * units_per_css_pixel, safe.y + 8.0 * units_per_css_pixel)
	var bottom_pad := maxf(14.0 * units_per_css_pixel, safe.w + 10.0 * units_per_css_pixel)
	var main_side := side * 1.32 * RIGHT_JOYSTICK_SCALE
	var main_center := Vector2(viewport_size.x - right_pad - main_side * 0.5, viewport_size.y - bottom_pad - main_side * 0.5)
	var jet_center := main_center - Vector2(main_side * 0.5 + gap + side * 0.5, 0.0)
	var grenade_center := jet_center - Vector2(side + gap, 0.0)
	_place("punch", main_center, main_side)
	_place("jetpack", jet_center, side)
	_place("grenade", grenade_center, side)
	_place("interact", grenade_center - Vector2(0.0, side + gap), side)
	var pause_side := maxf(48.0 * units_per_css_pixel, side * 0.82)
	_place("pause", Vector2(left_pad + 224.0 * units_per_css_pixel, top_pad + pause_side * 0.5), pause_side)
	var joystick_side := clampf(minf(css_size.y * 0.32, css_size.x * 0.24), 108.0, 164.0) * LEFT_JOYSTICK_SCALE * units_per_css_pixel
	joystick.size = Vector2.ONE * joystick_side
	joystick.position = Vector2(left_pad, viewport_size.y - bottom_pad - joystick_side)
	var aim_left := viewport_size.x * 0.37
	aim_area.position = Vector2(aim_left, 0.0)
	aim_area.size = Vector2(viewport_size.x - aim_left, viewport_size.y)
	_update_visibility()

func _place(key: String, center: Vector2, button_side: float) -> void:
	var button: Control = action_buttons[key]
	button.size = Vector2.ONE * button_side
	button.position = center - button.size * 0.5
