extends Control

signal jet_changed(active: bool)
signal punch_pressed
signal grenade_pressed
signal weapon_cycle_requested
signal zoom_cycle_requested

const Art = preload("res://scripts/art.gd")
const GlyphText = preload("res://scripts/glyph_label.gd")
const TAPE_ATLAS: Texture2D = preload("res://assets/hud_tape_atlas.png")
const GRENADE_ICON: Texture2D = preload("res://assets/hud_icon_grenade.png")
const JET_ICON: Texture2D = preload("res://assets/hud_icon_jet.png")
const PUNCH_ICON: Texture2D = preload("res://assets/hud_icon_punch.png")
const KillFeed = preload("res://scripts/kill_feed.gd")
const UI_SCALE := 0.78
const HP_TAPE_REGION := Rect2(128, 24, 1550, 364)
const WEAPON_TAPE_REGION := Rect2(22, 388, 583, 457)
const GRENADE_TAPE_REGION := Rect2(580, 467, 385, 359)
const JET_TAPE_REGION := Rect2(994, 462, 406, 376)
const PUNCH_TAPE_REGION := Rect2(1396, 468, 360, 366)

var health := 100
var fuel := 100.0
var ammo := 24
var capacity := 24
var grenades := 3
var weapon_name := "DUAL PISTOLS"
var weapon_index := 0
var kills := 0
var deaths := 0
var prompt := ""
var displayed_health := 100.0
var displayed_fuel := 100.0
var health_flash := 0.0

var fuel_art: TextureRect
var punch_button: TextureButton
var punch_icon: TextureRect
var jet_button: TextureButton
var jet_icon: TextureRect
var grenade_button: TextureButton
var grenade_icon: TextureRect
var grenade_count_panel: Panel
var grenade_count_badge: Label
var weapon_button: TextureButton
var zoom_button: Button
var zoom_label: GlyphLabel
var reload_panel: Panel
var reload_timer_label: GlyphLabel
var kill_feed: Control
var touch_hud: Control
var input_hint_label: GlyphLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 source = texture(TEXTURE, UV); float light = dot(source.rgb, vec3(0.299, 0.587, 0.114)); float ink = 1.0 - smoothstep(0.34, 0.63, light); COLOR = vec4(0.055, 0.055, 0.15, source.a * ink * COLOR.a); }"
	var sketch_material := ShaderMaterial.new()
	sketch_material.shader = shader
	fuel_art = _make_sketch(Art.hud_sketch("fuel_top"), sketch_material, self)
	fuel_art.position = Vector2(17, 111) * UI_SCALE
	fuel_art.size = Vector2(92, 39) * UI_SCALE
	var fuel_left := _make_sketch(Art.hud_sketch("fuel_left"), sketch_material, self)
	fuel_left.position = Vector2(17, 127) * UI_SCALE
	fuel_left.size = Vector2(13, 88) * UI_SCALE
	var fuel_right := _make_sketch(Art.hud_sketch("fuel_right"), sketch_material, self)
	fuel_right.position = Vector2(97, 127) * UI_SCALE
	fuel_right.size = Vector2(11, 88) * UI_SCALE
	var fuel_bottom := _make_sketch(Art.hud_sketch("fuel_bottom"), sketch_material, self)
	fuel_bottom.position = Vector2(22, 206) * UI_SCALE
	fuel_bottom.size = Vector2(84, 10) * UI_SCALE
	punch_button = _make_button(null, null)
	punch_button.pressed.connect(_on_punch_pressed)
	punch_icon = _make_action_icon(PUNCH_ICON, punch_button, sketch_material)
	jet_button = _make_button(null, null)
	jet_button.button_down.connect(_on_jet_down)
	jet_button.button_up.connect(_on_jet_up)
	jet_icon = _make_action_icon(JET_ICON, jet_button, sketch_material)
	grenade_button = _make_button(null, sketch_material)
	grenade_button.tooltip_text = "Кинути гранату (G)"
	grenade_button.pressed.connect(_on_grenade_pressed)
	grenade_icon = _make_action_icon(GRENADE_ICON, grenade_button, sketch_material)
	grenade_count_panel = Panel.new()
	grenade_count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grenade_badge_style := StyleBoxFlat.new()
	grenade_badge_style.bg_color = Color("f3ead1")
	grenade_badge_style.border_color = Color("292331")
	grenade_badge_style.set_border_width_all(1)
	grenade_badge_style.set_corner_radius_all(roundi(14.0 * UI_SCALE))
	grenade_count_panel.add_theme_stylebox_override("panel", grenade_badge_style)
	grenade_button.add_child(grenade_count_panel)
	grenade_count_badge = Label.new()
	grenade_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grenade_count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grenade_count_badge.add_theme_font_size_override("font_size", roundi(15.0 * UI_SCALE))
	grenade_count_badge.add_theme_color_override("font_color", Color("292331"))
	grenade_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grenade_count_badge.text = str(grenades)
	grenade_count_panel.add_child(grenade_count_badge)
	weapon_button = _make_button(Art.weapon(0), null)
	weapon_button.position = Vector2(132, 114) * UI_SCALE
	weapon_button.size = Vector2(108, 84) * UI_SCALE
	weapon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	weapon_button.tooltip_text = "Наступна зброя"
	weapon_button.pressed.connect(func() -> void: InputManager.pulse_action("weapon_next", "ui:weapon-next"))
	zoom_button = Button.new()
	zoom_button.focus_mode = Control.FOCUS_NONE
	zoom_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zoom_button.add_theme_stylebox_override("normal", _zoom_button_style(Color("f3ead1")))
	zoom_button.add_theme_stylebox_override("hover", _zoom_button_style(Color("e4d5b8")))
	zoom_button.add_theme_stylebox_override("pressed", _zoom_button_style(Color("c5b395")))
	zoom_button.add_theme_stylebox_override("focus", _zoom_button_style(Color("e4d5b8")))
	zoom_button.tooltip_text = "Зум карти: 2x → 4x → 6x → 8x → 1x"
	zoom_button.pressed.connect(_on_zoom_button_pressed)
	zoom_label = GlyphText.new()
	zoom_label.text = "1x"
	zoom_label.font_size = 16.0
	zoom_label.font_color = Color("292331")
	zoom_label.alignment = GlyphText.Align.CENTER
	zoom_label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zoom_button.add_child(zoom_label)
	add_child(zoom_button)
	reload_panel = Panel.new()
	reload_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_panel.visible = false
	var reload_style := StyleBoxFlat.new()
	reload_style.bg_color = Color("292331e8")
	reload_style.border_color = Color("c87962")
	reload_style.set_border_width_all(2)
	reload_style.set_corner_radius_all(7)
	reload_panel.add_theme_stylebox_override("panel", reload_style)
	var reload_heading := GlyphText.new()
	reload_heading.text = "ПЕРЕЗАРЯДКА"
	reload_heading.font_size = 17.0
	reload_heading.font_color = Color("f3ead1")
	reload_heading.alignment = GlyphText.Align.CENTER
	reload_heading.vertical_alignment = GlyphText.VerticalAlign.CENTER
	reload_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_heading.position = Vector2(10.0, 5.0)
	reload_heading.size = Vector2(190.0, 42.0)
	reload_panel.add_child(reload_heading)
	reload_timer_label = GlyphText.new()
	reload_timer_label.text = "0.0с"
	reload_timer_label.font_size = 24.0
	reload_timer_label.font_color = Color("f0a36c")
	reload_timer_label.alignment = GlyphText.Align.CENTER
	reload_timer_label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	reload_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_timer_label.position = Vector2(203.0, 4.0)
	reload_timer_label.size = Vector2(82.0, 44.0)
	reload_panel.add_child(reload_timer_label)
	add_child(reload_panel)
	input_hint_label = GlyphText.new()
	input_hint_label.font_size = 13.0
	input_hint_label.font_color = Color("292331")
	input_hint_label.alignment = GlyphText.Align.CENTER
	input_hint_label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	input_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(input_hint_label)
	InputManager.active_input_device_changed.connect(_update_input_hint)
	_update_input_hint(InputManager.get_active_input_device())
	kill_feed = KillFeed.new()
	add_child(kill_feed)
	touch_hud = preload("res://scripts/touch_hud.gd").new()
	add_child(touch_hud)
	touch_hud.visibility_changed.connect(_sync_action_button_visibility)
	resized.connect(_layout_buttons)
	_layout_buttons()
	_sync_action_button_visibility()

func _make_sketch(texture: Texture2D, sketch_material: Material, parent: Node) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = sketch_material
	parent.add_child(rect)
	return rect

func _make_action_icon(texture: Texture2D, parent: Node, sketch_material: Material) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = sketch_material
	parent.add_child(rect)
	return rect

func _make_button(texture: Texture2D, sketch_material: Material) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.material = sketch_material
	add_child(button)
	return button

func _layout_buttons() -> void:
	var width := size.x
	var height := size.y
	var compact := width < 720.0
	var button_side := (96.0 if compact else 120.0) * UI_SCALE
	var button_gap := 13.0 * UI_SCALE
	if width < 420.0:
		var scale_value := width / 420.0
		button_side *= scale_value
		button_gap *= scale_value
	punch_button.size = Vector2.ONE * button_side
	jet_button.size = Vector2.ONE * button_side
	grenade_button.size = Vector2.ONE * button_side
	punch_button.position = Vector2(width - button_side - 18.0 * UI_SCALE, height - button_side - 18.0 * UI_SCALE)
	jet_button.position = punch_button.position - Vector2(button_side + button_gap, 0.0)
	grenade_button.position = jet_button.position - Vector2(button_side + button_gap, 0.0)
	zoom_button.size = Vector2.ONE * 48.0
	zoom_button.position = Vector2(maxf(12.0, width - 152.0), 12.0)
	reload_panel.size = Vector2(295.0, 52.0)
	reload_panel.position = Vector2((width - reload_panel.size.x) * 0.5, 100.0)
	input_hint_label.size = Vector2(minf(520.0, maxf(120.0, width - 240.0)), 27.0)
	input_hint_label.position = Vector2((width - input_hint_label.size.x) * 0.5, 8.0)
	var badge_side := minf(28.0 * UI_SCALE, button_side * 0.32)
	var badge_margin := button_side * 0.07
	grenade_count_panel.size = Vector2.ONE * badge_side
	grenade_count_panel.position = grenade_button.size - Vector2.ONE * (badge_side + badge_margin)
	grenade_count_badge.position = Vector2.ZERO
	grenade_count_badge.size = grenade_count_panel.size
	var icon_side := button_side * 0.57
	punch_icon.size = Vector2.ONE * icon_side
	punch_icon.position = (punch_button.size - punch_icon.size) * 0.5
	jet_icon.size = Vector2.ONE * icon_side
	jet_icon.position = (jet_button.size - jet_icon.size) * 0.5
	icon_side = button_side * 0.57
	grenade_icon.size = Vector2.ONE * icon_side
	grenade_icon.position = (grenade_button.size - grenade_icon.size) * 0.5 - Vector2(badge_side * 0.25, badge_side * 0.2)
	_sync_action_button_visibility()

func _sync_action_button_visibility() -> void:
	if touch_hud == null or not is_instance_valid(touch_hud):
		return
	var show_touch_overlay: bool = touch_hud.visible
	punch_button.visible = not show_touch_overlay
	jet_button.visible = not show_touch_overlay
	grenade_button.visible = not show_touch_overlay

func _process(delta: float) -> void:
	displayed_health = move_toward(displayed_health, float(health), 120.0 * delta)
	displayed_fuel = move_toward(displayed_fuel, fuel, 80.0 * delta)
	health_flash = maxf(0.0, health_flash - delta * 2.5)
	punch_button.modulate = Color("cfc5b2") if punch_button.button_pressed else Color.WHITE
	jet_button.modulate = Color("cfc5b2") if jet_button.button_pressed else Color.WHITE
	grenade_button.modulate = Color("cfc5b2") if grenade_button.button_pressed else Color.WHITE
	queue_redraw()

func set_stats(new_health: int, new_fuel: float, new_ammo: int, new_capacity: int, new_weapon_name: String, new_weapon_index: int, new_grenades: int) -> void:
	if new_health < health:
		health_flash = 1.0
	health = new_health
	fuel = new_fuel
	ammo = new_ammo
	capacity = new_capacity
	grenades = new_grenades
	grenade_count_badge.text = str(grenades)
	grenade_button.disabled = grenades <= 0
	if is_instance_valid(touch_hud):
		touch_hud.set_grenades(grenades)
	weapon_name = new_weapon_name
	if weapon_index != new_weapon_index:
		weapon_index = new_weapon_index
		weapon_button.texture_normal = Art.weapon(weapon_index)

func is_action_at(point: Vector2) -> bool:
	return punch_button.button_pressed or jet_button.button_pressed or grenade_button.button_pressed or punch_button.get_global_rect().has_point(point) or jet_button.get_global_rect().has_point(point) or grenade_button.get_global_rect().has_point(point) or weapon_button.get_global_rect().has_point(point) or zoom_button.get_global_rect().has_point(point)

func set_zoom_level(value: float) -> void:
	zoom_label.text = "%dx" % roundi(value)

func set_reload_remaining(remaining: float) -> void:
	var seconds_left := maxf(0.0, remaining)
	reload_panel.visible = seconds_left > 0.0
	if reload_panel.visible:
		reload_timer_label.text = "%.1fс" % seconds_left

func set_context_action_available(available: bool) -> void:
	if is_instance_valid(touch_hud):
		touch_hud.set_interact_available(available)

func _on_zoom_button_pressed() -> void:
	Sfx.play_sfx(&"ui_click", -8.0, 1.0, 0.04)
	zoom_cycle_requested.emit()

func _update_input_hint(device: String) -> void:
	if input_hint_label == null:
		return
	input_hint_label.visible = device != "touch"
	match device:
		"touch":
			input_hint_label.text = "JOYSTICK MOVE  ·  FIRE  ·  JUMP / FLY  ·  E PICKUP"
		"gamepad":
			input_hint_label.text = "LEFT STICK MOVE  ·  A JUMP  ·  X FIRE  ·  Y PICKUP"
		_:
			input_hint_label.text = "A / D OR ARROWS MOVE  ·  SPACE JUMP  ·  CLICK FIRE  ·  E PICKUP"

func _zoom_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("292331")
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	return style

func show_player_kill(killer: String, victim: String) -> void:
	kill_feed.show_player_kill(killer, victim)

func _on_punch_pressed() -> void:
	InputManager.pulse_action("skill_1", "ui:punch")

func _on_grenade_pressed() -> void:
	InputManager.pulse_action("skill_4", "ui:grenade")

func _on_jet_down() -> void:
	InputManager.press_action("jump", "ui:jetpack")
	jet_changed.emit(true)

func _on_jet_up() -> void:
	InputManager.release_action("jump", "ui:jetpack")
	jet_changed.emit(false)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * UI_SCALE)
	draw_texture_rect_region(TAPE_ATLAS, Rect2(8, 6, 326, 76), HP_TAPE_REGION)
	draw_texture_rect_region(TAPE_ATLAS, Rect2(119, 106, 142, 112), WEAPON_TAPE_REGION)
	if not touch_hud.visible:
		var action_buttons := [grenade_button, jet_button, punch_button]
		var action_regions := [GRENADE_TAPE_REGION, JET_TAPE_REGION, PUNCH_TAPE_REGION]
		for index in range(action_buttons.size()):
			var button: TextureButton = action_buttons[index]
			var source: Rect2 = action_regions[index]
			var destination := Rect2(button.position / UI_SCALE, button.size / UI_SCALE)
			var center := destination.get_center()
			var backing_radius := destination.size.x * 0.30
			draw_circle(center, backing_radius, Color("f3ead1"))
			draw_arc(center, backing_radius, 0.0, TAU, 48, Color("c7baa0"), 1.0, true)
			var aspect := source.size.x / source.size.y
			var fitted_size := destination.size
			if fitted_size.x / fitted_size.y > aspect:
				fitted_size.x = fitted_size.y * aspect
			else:
				fitted_size.y = fitted_size.x / aspect
			destination.position += (destination.size - fitted_size) * 0.5
			destination.size = fitted_size
			draw_texture_rect_region(TAPE_ATLAS, destination, source)
	var health_ratio := clampf(displayed_health / 100.0, 0.0, 1.0)
	var bar_left := 41.0
	var bar_right := 301.0
	var fill_end := bar_left + (bar_right - bar_left) * health_ratio
	draw_rect(Rect2(bar_left, 36, bar_right - bar_left, 24), Color("e7dce0"))
	draw_rect(Rect2(bar_left, 36, fill_end - bar_left, 24), Color("d4857f").lerp(Color.WHITE, health_flash * 0.4))
	for i in range(23):
		var x := bar_left + i * 11.5
		if x < fill_end:
			draw_line(Vector2(x, 59), Vector2(minf(x + 18.0, fill_end), 37), Color("292331aa"), 1.2)
		else:
			draw_line(Vector2(x, 59), Vector2(minf(x + 18.0, bar_right), 37), Color("29233168"), 1.2)
			draw_line(Vector2(x, 37), Vector2(minf(x + 18.0, bar_right), 59), Color("29233168"), 1.2)
	var level := 198.0 - 56.0 * clampf(displayed_fuel / 100.0, 0.0, 1.0)
	var wave := sin(Time.get_ticks_msec() * 0.006) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(30, level + wave), Vector2(51, level - wave), Vector2(76, level + wave), Vector2(99, level - wave), Vector2(99, 200), Vector2(30, 200)]), Color("e5ae72"))
	for tick in range(12):
		var active := float(tick) < float(ammo) / maxf(float(capacity), 1.0) * 12.0
		draw_rect(Rect2(140 + tick * 8.5, 201, 6.2, 7), Color("292331") if active else Color("c5b9ad"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fps_position := Vector2(size.x - 88.0, 29.0)
	var fps_text := "%d FPS" % Engine.get_frames_per_second()
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(ThemeDB.fallback_font, fps_position + offset, fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("f7f2e8"))
	draw_string(ThemeDB.fallback_font, fps_position, fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("292331"))
	var mouse := get_viewport().get_mouse_position()
	if InputManager.get_active_input_device() == "mouse" and not is_action_at(mouse):
		draw_texture_rect(Art.region(Art.CROSSHAIR, Rect2(0, 325, 300, 280)), Rect2(mouse - Vector2(15, 15), Vector2(30, 30)), false)
