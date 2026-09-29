extends Control

const GlyphText = preload("res://scripts/glyph_label.gd")
const OrientationHint = preload("res://scripts/orientation_hint.gd")
const BACKDROP: Texture2D = preload("res://assets/menu_backdrop.png")
const BOT_TILE: Texture2D = preload("res://assets/menu_tile_bots.png")
const WLAN_TILE: Texture2D = preload("res://assets/menu_tile_wlan.png")
const ONLINE_TILE: Texture2D = preload("res://assets/menu_tile_online.png")

var screen_layer: Control
var current_screen := "home"
var home_title: Control
var home_subtitle: Control
var home_cards: Array[Button] = []
var settings_button: Button
var exit_button: Button
var update_status_button: Button
var update_status_label: GlyphText
var player_tag: Control
var settings_panel: Control
var settings_name: LineEdit
var settings_volume: HSlider
var settings_fullscreen: Button
var settings_fullscreen_label: GlyphText
var settings_volume_label: GlyphText
var notice_panel: Control
var orientation_hint: CanvasLayer
var wlan_panel: Control
var wlan_address: LineEdit
var wlan_message: GlyphText
var wlan_heading: Control
var wlan_instructions: Control
var wlan_rooms_heading: Control
var wlan_rooms_scroll: ScrollContainer
var wlan_rooms_list: VBoxContainer
var wlan_browser_join_button: Button
var wlan_host_button: Button
var wlan_search_button: Button
var wlan_manual_button: Button
var wlan_manual_join_button: Button
var wlan_manual_open := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Profile.apply_settings()
	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var wash := ColorRect.new()
	wash.color = Color(0.10, 0.075, 0.055, 0.18)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	screen_layer = Control.new()
	screen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_layer)
	orientation_hint = OrientationHint.new()
	add_child(orientation_hint)
	get_viewport().size_changed.connect(_layout_screen)
	Wlan.connection_established.connect(_on_wlan_connected)
	Wlan.connection_failed.connect(_on_wlan_failed)
	Wlan.rooms_changed.connect(_on_wlan_rooms_changed)
	UpdateManager.status_changed.connect(_on_update_status_changed)
	_show_home()
	UpdateManager.check_for_updates()
	call_deferred("_layout_screen")

func _unhandled_input(event: InputEvent) -> void:
	if InputManager.is_action_just_pressed("cancel") and current_screen != "home":
		_show_home()
		get_viewport().set_input_as_handled()

func _show_home() -> void:
	Wlan.cancel_room_search()
	Profile.apply_settings()
	_clear_screen()
	current_screen = "home"
	home_title = _make_label("NOTEBOOK", 62.0, Color("261f19"), GlyphText.Align.CENTER)
	home_subtitle = _make_label("ARENA", 70.0, Color("a83328"), GlyphText.Align.CENTER)
	screen_layer.add_child(home_title)
	screen_layer.add_child(home_subtitle)
	home_cards.clear()
	home_cards.append(_make_card("ЗВИЧАЙНА ГРА", "ПРОТИ БОТІВ", BOT_TILE, Color("fff1d6"), Rect2(0.0, 155.0, 2010.0, 465.0), Callable(self, "_start_local_arena")))
	home_cards.append(_make_card("CO-OP WLAN", "ЛОКАЛЬНА МЕРЕЖА", WLAN_TILE, Color("211b15"), Rect2(0.0, 235.0, 1916.0, 420.0), Callable(self, "_show_wlan_notice")))
	home_cards.append(_make_card("ONLINE", "МЕРЕЖЕВА ГРА", ONLINE_TILE, Color("211b15"), Rect2(0.0, 155.0, 2132.0, 450.0), Callable(self, "_show_online_notice")))
	settings_button = _make_button("SETTINGS", Color("29231d"), Color("f3e8cf"), Callable(self, "_show_settings"))
	screen_layer.add_child(settings_button)
	exit_button = _make_button("ВИЙТИ", Color("29231d"), Color("f3e8cf"), Callable(self, "_exit_game"))
	screen_layer.add_child(exit_button)
	update_status_button = _make_button("", Color("f3e8cf"), Color.BLACK, Callable(self, "_on_update_status_pressed"))
	update_status_label = _make_label(UpdateManager.status_message, 13.0, Color.BLACK, GlyphText.Align.LEFT)
	update_status_label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	update_status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	update_status_label.offset_left = 9.0
	update_status_label.offset_right = -9.0
	update_status_button.add_child(update_status_label)
	update_status_button.disabled = not UpdateManager.can_retry and not UpdateManager.can_install
	screen_layer.add_child(update_status_button)
	player_tag = _make_label("ГРАВЕЦЬ: " + Profile.player_name, 18.0, Color("2b241e"), GlyphText.Align.CENTER)
	screen_layer.add_child(player_tag)
	_layout_screen()
	if not home_cards.is_empty():
		home_cards[0].grab_focus()

func _show_settings() -> void:
	_clear_screen()
	current_screen = "settings"
	settings_panel = _make_panel(Vector2(560.0, 425.0))
	screen_layer.add_child(settings_panel)
	var heading := _make_label("НАЛАШТУВАННЯ", 34.0, Color("29231d"), GlyphText.Align.CENTER)
	heading.position = Vector2(24.0, 19.0)
	heading.size = Vector2(512.0, 48.0)
	settings_panel.add_child(heading)
	var name_label := _make_label("ІМ'Я ГРАВЦЯ", 20.0, Color("29231d"), GlyphText.Align.LEFT)
	name_label.position = Vector2(32.0, 86.0)
	name_label.size = Vector2(250.0, 30.0)
	settings_panel.add_child(name_label)
	settings_name = LineEdit.new()
	settings_name.text = Profile.player_name
	settings_name.max_length = 18
	settings_name.placeholder_text = "Player"
	settings_name.position = Vector2(30.0, 118.0)
	settings_name.size = Vector2(500.0, 49.0)
	settings_name.add_theme_font_size_override("font_size", 22)
	settings_name.add_theme_color_override("font_color", Color("29231d"))
	settings_name.add_theme_color_override("font_selected_color", Color("f3e8cf"))
	settings_name.add_theme_color_override("selection_color", Color("a83a2d"))
	settings_name.add_theme_stylebox_override("normal", _line_style(Color("f5ecd9")))
	settings_name.add_theme_stylebox_override("focus", _line_style(Color("fff8e9")))
	settings_panel.add_child(settings_name)
	var volume_label := _make_label("ГРОМКІСТЬ", 20.0, Color("29231d"), GlyphText.Align.LEFT)
	volume_label.position = Vector2(32.0, 190.0)
	volume_label.size = Vector2(250.0, 30.0)
	settings_panel.add_child(volume_label)
	settings_volume_label = _make_label("78%", 18.0, Color("a83a2d"), GlyphText.Align.RIGHT)
	settings_volume_label.position = Vector2(438.0, 190.0)
	settings_volume_label.size = Vector2(88.0, 30.0)
	settings_panel.add_child(settings_volume_label)
	settings_volume = HSlider.new()
	settings_volume.min_value = 0.0
	settings_volume.max_value = 1.0
	settings_volume.step = 0.01
	settings_volume.value = Profile.master_volume
	settings_volume.position = Vector2(32.0, 224.0)
	settings_volume.size = Vector2(496.0, 38.0)
	settings_volume.add_theme_stylebox_override("slider", _line_style(Color("d6c6a8")))
	settings_volume.add_theme_stylebox_override("grabber_area", _line_style(Color("a83a2d")))
	settings_volume.add_theme_stylebox_override("grabber_area_highlight", _line_style(Color("c45543")))
	settings_volume.value_changed.connect(_on_volume_preview)
	settings_panel.add_child(settings_volume)
	settings_fullscreen = _make_button("", Color("e2d3b5"), Color("29231d"), Callable(self, "_toggle_fullscreen_preview"))
	settings_fullscreen.toggle_mode = true
	settings_fullscreen.button_pressed = Profile.fullscreen
	settings_fullscreen.position = Vector2(30.0, 278.0)
	settings_fullscreen.size = Vector2(500.0, 48.0)
	settings_panel.add_child(settings_fullscreen)
	settings_fullscreen_label = _make_label("FULLSCREEN: " + ("ON" if Profile.fullscreen else "OFF"), 18.0, Color("29231d"), GlyphText.Align.LEFT)
	settings_fullscreen_label.vertical_alignment = GlyphText.VerticalAlign.CENTER
	settings_fullscreen_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_fullscreen_label.offset_left = 22.0
	settings_fullscreen_label.offset_right = -23.0
	settings_fullscreen.add_child(settings_fullscreen_label)
	var back := _make_button("НАЗАД", Color("d9ccb0"), Color("29231d"), Callable(self, "_show_home"))
	back.position = Vector2(30.0, 350.0)
	back.size = Vector2(240.0, 48.0)
	settings_panel.add_child(back)
	var save := _make_button("ЗБЕРЕГТИ", Color("a83a2d"), Color("f3e8cf"), Callable(self, "_save_settings"))
	save.position = Vector2(290.0, 350.0)
	save.size = Vector2(240.0, 48.0)
	settings_panel.add_child(save)
	_layout_screen()
	settings_name.grab_focus()
	settings_name.caret_column = settings_name.text.length()

func _show_wlan_notice() -> void:
	_clear_screen()
	current_screen = "wlan"
	wlan_manual_open = false
	wlan_panel = _make_panel(Vector2(580.0, 394.0))
	screen_layer.add_child(wlan_panel)
	wlan_heading = _make_label("CO-OP WLAN", 36.0, Color("a83a2d"), GlyphText.Align.CENTER)
	wlan_heading.position = Vector2(24.0, 18.0)
	wlan_heading.size = Vector2(532.0, 44.0)
	wlan_panel.add_child(wlan_heading)
	var instructions_text := "ВІДКРИЙТЕ СПИСОК КІМНАТ АБО СТВОРІТЬ СВОЮ. ОБИДВА ПРИСТРОЇ МАЮТЬ БУТИ В ОДНІЙ WI-FI МЕРЕЖІ."
	if OS.has_feature("web"):
		instructions_text = "БРАУЗЕР ПІДКЛЮЧИТЬСЯ ДО ХОСТА, ЯКЩО ГРУ ВІДКРИТО З ЙОГО ЛОКАЛЬНОГО ПОСИЛАННЯ."
	wlan_instructions = _make_label(instructions_text, 14.0, Color("29231d"), GlyphText.Align.CENTER)
	wlan_instructions.position = Vector2(28.0, 68.0)
	wlan_instructions.size = Vector2(524.0, 40.0)
	wlan_panel.add_child(wlan_instructions)
	if OS.has_feature("web"):
		wlan_browser_join_button = _make_button("ПРИЄДНАТИСЯ ДО ЦЬОГО ХОСТА", Color("a83a2d"), Color("f3e8cf"), Callable(self, "_join_browser_host"))
		wlan_browser_join_button.position = Vector2(28.0, 118.0)
		wlan_browser_join_button.size = Vector2(524.0, 50.0)
		wlan_browser_join_button.disabled = _default_wlan_address().is_empty()
		wlan_panel.add_child(wlan_browser_join_button)
	else:
		wlan_host_button = _make_button("СТВОРИТИ ХОСТ", Color("a83a2d"), Color("f3e8cf"), Callable(self, "_start_wlan_host"))
		wlan_host_button.position = Vector2(28.0, 116.0)
		wlan_host_button.size = Vector2(250.0, 48.0)
		wlan_panel.add_child(wlan_host_button)
		wlan_search_button = _make_button("ЗНАЙТИ КІМНАТИ", Color("29231d"), Color("f3e8cf"), Callable(self, "_search_wlan_rooms"))
		wlan_search_button.position = Vector2(302.0, 116.0)
		wlan_search_button.size = Vector2(250.0, 48.0)
		wlan_panel.add_child(wlan_search_button)
		wlan_rooms_heading = _make_label("ІГРИ У ЦІЙ МЕРЕЖІ", 15.0, Color("29231d"), GlyphText.Align.LEFT)
		wlan_rooms_heading.position = Vector2(30.0, 171.0)
		wlan_rooms_heading.size = Vector2(500.0, 23.0)
		wlan_panel.add_child(wlan_rooms_heading)
		wlan_rooms_scroll = ScrollContainer.new()
		wlan_rooms_scroll.position = Vector2(28.0, 196.0)
		wlan_rooms_scroll.size = Vector2(524.0, 106.0)
		wlan_rooms_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		wlan_panel.add_child(wlan_rooms_scroll)
		wlan_rooms_list = VBoxContainer.new()
		wlan_rooms_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wlan_rooms_list.add_theme_constant_override("separation", 5)
		wlan_rooms_scroll.add_child(wlan_rooms_list)
	wlan_address = LineEdit.new()
	wlan_address.text = _default_wlan_address()
	wlan_address.placeholder_text = "192.168.1.20:8910"
	wlan_address.position = Vector2(28.0, 389.0)
	wlan_address.size = Vector2(524.0, 44.0)
	wlan_address.add_theme_font_size_override("font_size", 20)
	wlan_address.add_theme_color_override("font_color", Color("29231d"))
	wlan_address.add_theme_stylebox_override("normal", _line_style(Color("f5ecd9")))
	wlan_address.add_theme_stylebox_override("focus", _line_style(Color("fff8e9")))
	wlan_address.visible = false
	wlan_panel.add_child(wlan_address)
	wlan_manual_join_button = _make_button("ПІДКЛЮЧИТИСЯ ЗА АДРЕСОЮ", Color("29231d"), Color("f3e8cf"), Callable(self, "_join_wlan"))
	wlan_manual_join_button.position = Vector2(28.0, 442.0)
	wlan_manual_join_button.size = Vector2(524.0, 44.0)
	wlan_manual_join_button.visible = false
	wlan_panel.add_child(wlan_manual_join_button)
	var initial_message := "ШУКАЮ КІМНАТИ…"
	if OS.has_feature("web"):
		initial_message = "ВІДКРИЙТЕ ГРУ ЧЕРЕЗ ЛОКАЛЬНЕ ПОСИЛАННЯ ХОСТА АБО ВКАЖІТЬ ЙОГО АДРЕСУ."
	wlan_message = _make_label(initial_message, 13.0, Color("57483a"), GlyphText.Align.CENTER)
	wlan_message.position = Vector2(28.0, 305.0)
	wlan_message.size = Vector2(524.0, 34.0)
	wlan_panel.add_child(wlan_message)
	wlan_manual_button = _make_button("ВВЕСТИ АДРЕС ВРУЧНУ", Color("d9ccb0"), Color("29231d"), Callable(self, "_toggle_manual_wlan"))
	wlan_manual_button.position = Vector2(28.0, 344.0)
	wlan_manual_button.size = Vector2(524.0, 40.0)
	wlan_panel.add_child(wlan_manual_button)
	_layout_wlan_panel()
	if not OS.has_feature("web"):
		_search_wlan_rooms()

func _layout_wlan_panel() -> void:
	if not is_instance_valid(wlan_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var is_web := OS.has_feature("web")
	var panel_width := minf(580.0, viewport_size.x - 28.0)
	var expanded_height := 386.0 if is_web else 488.0
	var panel_height := expanded_height if wlan_manual_open else (286.0 if is_web else 394.0)
	panel_height = minf(panel_height, viewport_size.y - 24.0)
	wlan_panel.size = Vector2(panel_width, panel_height)
	wlan_panel.position = (viewport_size - wlan_panel.size) * 0.5
	var inner_width := panel_width - 56.0
	wlan_heading.position.x = (panel_width - wlan_heading.size.x) * 0.5
	wlan_instructions.size.x = inner_width
	if is_web:
		wlan_browser_join_button.position = Vector2(28.0, 118.0)
		wlan_browser_join_button.size = Vector2(inner_width, 50.0)
		wlan_message.position = Vector2(28.0, 176.0)
		wlan_message.size = Vector2(inner_width, 46.0)
		wlan_manual_button.position = Vector2(28.0, 232.0)
		wlan_manual_button.size = Vector2(inner_width, 40.0)
	else:
		var button_width := (inner_width - 12.0) * 0.5
		wlan_host_button.position = Vector2(28.0, 116.0)
		wlan_host_button.size = Vector2(button_width, 48.0)
		wlan_search_button.position = Vector2(40.0 + button_width, 116.0)
		wlan_search_button.size = Vector2(button_width, 48.0)
		wlan_rooms_heading.position = Vector2(30.0, 171.0)
		wlan_rooms_heading.size.x = inner_width - 4.0
		wlan_rooms_scroll.position = Vector2(28.0, 196.0)
		wlan_rooms_scroll.size = Vector2(inner_width, 106.0)
		wlan_message.position = Vector2(28.0, 305.0)
		wlan_message.size = Vector2(inner_width, 34.0)
		wlan_manual_button.position = Vector2(28.0, 344.0)
		wlan_manual_button.size = Vector2(inner_width, 40.0)
	wlan_address.position = Vector2(28.0, 389.0 if not is_web else 278.0)
	wlan_address.size = Vector2(inner_width, 44.0)
	wlan_manual_join_button.position = Vector2(28.0, 442.0 if not is_web else 330.0)
	wlan_manual_join_button.size = Vector2(inner_width, 44.0)

func _toggle_manual_wlan() -> void:
	wlan_manual_open = not wlan_manual_open
	wlan_address.visible = wlan_manual_open
	wlan_manual_join_button.visible = wlan_manual_open
	_layout_wlan_panel()
	if wlan_manual_open:
		wlan_address.grab_focus()
		wlan_address.caret_column = wlan_address.text.length()

func _search_wlan_rooms() -> void:
	if not is_instance_valid(wlan_message):
		return
	wlan_message.text = "ШУКАЮ КІМНАТИ В МЕРЕЖІ…"
	if Wlan.search_rooms() != OK:
		wlan_message.text = Wlan.status_message

func _on_wlan_rooms_changed(rooms: Array, scan_finished: bool) -> void:
	if current_screen != "wlan" or not is_instance_valid(wlan_rooms_list):
		return
	for child in wlan_rooms_list.get_children():
		wlan_rooms_list.remove_child(child)
		child.queue_free()
	for room in rooms:
		if not room is Dictionary:
			continue
		var room_name := str(room.get("host_name", "HOST"))
		var player_count := int(room.get("players", 1))
		var player_limit := int(room.get("player_limit", Wlan.MAX_PLAYERS))
		var address := str(room.get("address", ""))
		var join := _make_button("", Color("eadfc6"), Color("29231d"), Callable(self, "_join_discovered_room").bind(address))
		join.custom_minimum_size = Vector2(0.0, 44.0)
		join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := _make_label("%s   •   %d/%d гравців" % [room_name, player_count, player_limit], 16.0, Color("29231d"), GlyphText.Align.CENTER)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		join.add_child(label)
		wlan_rooms_list.add_child(join)
	if scan_finished:
		if rooms.is_empty():
			wlan_message.text = "КІМНАТ НЕ ЗНАЙДЕНО. ПЕРЕВІРТЕ WI-FI АБО ВВЕДІТЬ АДРЕСУ ВРУЧНУ."
		else:
			wlan_message.text = "ЗНАЙДЕНО КІМНАТ: %d. НАТИСНІТЬ, ЩОБ УВІЙТИ." % rooms.size()

func _join_discovered_room(address: String) -> void:
	_join_wlan_at(address)

func _show_online_notice() -> void:
	_show_mode_notice("ONLINE")

func _show_mode_notice(mode_name: String) -> void:
	_clear_screen()
	current_screen = "notice"
	notice_panel = _make_panel(Vector2(500.0, 260.0))
	screen_layer.add_child(notice_panel)
	var heading := _make_label(mode_name, 39.0, Color("a83a2d"), GlyphText.Align.CENTER)
	heading.position = Vector2(20.0, 33.0)
	heading.size = Vector2(460.0, 64.0)
	notice_panel.add_child(heading)
	var message := _make_label("ПОКИ НЕДОСТУПНО", 25.0, Color("29231d"), GlyphText.Align.CENTER)
	message.position = Vector2(25.0, 112.0)
	message.size = Vector2(450.0, 45.0)
	notice_panel.add_child(message)
	var back := _make_button("НАЗАД", Color("29231d"), Color("f3e8cf"), Callable(self, "_show_home"))
	back.position = Vector2(130.0, 190.0)
	back.size = Vector2(240.0, 48.0)
	notice_panel.add_child(back)
	_layout_screen()
	back.grab_focus()

func _make_card(title: String, subtitle: String, tile: Texture2D, ink: Color, region: Rect2, action: Callable) -> Button:
	var button := _make_button("", Color.TRANSPARENT, ink, action)
	var transparent_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", transparent_style)
	button.add_theme_stylebox_override("pressed", transparent_style)
	button.add_theme_stylebox_override("focus", transparent_style)
	screen_layer.add_child(button)
	var tile_view := TextureRect.new()
	var cropped_tile := AtlasTexture.new()
	cropped_tile.atlas = tile
	cropped_tile.region = region
	tile_view.texture = cropped_tile
	tile_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile_view.stretch_mode = TextureRect.STRETCH_SCALE
	tile_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(tile_view)
	var first := _make_label(title, 26.0, ink, GlyphText.Align.LEFT)
	first.position = Vector2(150.0, 24.0 if not subtitle.is_empty() else 28.0)
	first.size = Vector2(358.0, 36.0)
	first.z_index = 1
	button.add_child(first)
	if not subtitle.is_empty():
		var second := _make_label(subtitle, 16.0, ink.darkened(0.04), GlyphText.Align.LEFT)
		second.position = Vector2(152.0, 58.0)
		second.size = Vector2(356.0, 24.0)
		second.z_index = 1
		button.add_child(second)
	button.mouse_entered.connect(_on_card_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_card_mouse_exited.bind(button))
	return button

func _make_button(caption: String, fill: Color, ink: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _button_style(fill, Color("29231d")))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08), Color("a83a2d")))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.08), Color("29231d")))
	button.add_theme_stylebox_override("focus", _button_style(fill, Color("a83a2d")))
	if not caption.is_empty():
		var label := _make_label(caption, 18.0, ink, GlyphText.Align.CENTER)
		label.vertical_alignment = GlyphText.VerticalAlign.CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(label)
	button.mouse_entered.connect(_on_button_hover)
	button.pressed.connect(_on_button_click)
	button.pressed.connect(action)
	return button

func _on_button_hover() -> void:
	Sfx.play_sfx(&"ui_click", -17.0, 1.3, 0.03)

func _on_button_click() -> void:
	Sfx.play_sfx(&"ui_click", -6.0, 0.92, 0.04)

func _on_card_mouse_entered(button: Button) -> void:
	button.modulate = Color(1.08, 1.06, 1.02, 1.0)

func _on_card_mouse_exited(button: Button) -> void:
	button.modulate = Color.WHITE

func _make_label(caption: String, text_size: float, ink: Color, align: GlyphText.Align) -> GlyphLabel:
	var label := GlyphText.new()
	label.text = caption
	label.font_size = text_size
	label.font_color = ink
	label.alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_panel(panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _button_style(Color("eadfc6"), Color("29231d")))
	return panel

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _line_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("57483a")
	style.set_border_width_all(2)
	return style

func _layout_screen() -> void:
	if not is_instance_valid(screen_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if current_screen == "home" and is_instance_valid(settings_button):
		var panel_width := minf(530.0, viewport_size.x * 0.46)
		var left := maxf(viewport_size.x * 0.515, viewport_size.x - panel_width - 34.0)
		home_title.position = Vector2(left, viewport_size.y * 0.11)
		home_title.size = Vector2(panel_width, 70.0)
		home_subtitle.position = Vector2(left, viewport_size.y * 0.11 + 60.0)
		home_subtitle.size = Vector2(panel_width, 78.0)
		var button_y := viewport_size.y * 0.40
		var heights := [110.0, 96.0, 96.0]
		for index in range(home_cards.size()):
			var card := home_cards[index]
			card.position = Vector2(left, button_y)
			card.size = Vector2(panel_width, heights[index])
			button_y += heights[index] + 14.0
		settings_button.position = Vector2(viewport_size.x - 178.0, 24.0)
		settings_button.size = Vector2(150.0, 42.0)
		update_status_button.position = Vector2(24.0, 24.0)
		update_status_button.size = Vector2(minf(400.0, viewport_size.x * 0.44), 42.0)
		exit_button.position = Vector2(24.0, viewport_size.y - 66.0)
		exit_button.size = Vector2(150.0, 42.0)
		player_tag.position = Vector2(left, viewport_size.y - 53.0)
		player_tag.size = Vector2(panel_width, 28.0)
	elif current_screen == "settings" and is_instance_valid(settings_panel):
		settings_panel.position = (viewport_size - settings_panel.size) * 0.5
	elif current_screen == "notice" and is_instance_valid(notice_panel):
		notice_panel.position = (viewport_size - notice_panel.size) * 0.5
	elif current_screen == "wlan" and is_instance_valid(wlan_panel):
		_layout_wlan_panel()

func _clear_screen() -> void:
	if is_instance_valid(screen_layer):
		for child in screen_layer.get_children():
			screen_layer.remove_child(child)
			child.queue_free()
	home_title = null
	home_subtitle = null
	home_cards.clear()
	settings_button = null
	exit_button = null
	update_status_button = null
	update_status_label = null
	player_tag = null
	settings_panel = null
	settings_name = null
	settings_volume = null
	settings_fullscreen = null
	settings_fullscreen_label = null
	settings_volume_label = null
	notice_panel = null
	wlan_panel = null
	wlan_address = null
	wlan_message = null
	wlan_heading = null
	wlan_instructions = null
	wlan_rooms_heading = null
	wlan_rooms_scroll = null
	wlan_rooms_list = null
	wlan_browser_join_button = null
	wlan_host_button = null
	wlan_search_button = null
	wlan_manual_button = null
	wlan_manual_join_button = null

func _on_volume_preview(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value)
	if is_instance_valid(settings_volume_label):
		settings_volume_label.text = "%d%%" % roundi(value * 100.0)

func _toggle_fullscreen_preview() -> void:
	if is_instance_valid(settings_fullscreen_label):
		settings_fullscreen_label.text = "FULLSCREEN: " + ("ON" if settings_fullscreen.button_pressed else "OFF")

func _save_settings() -> void:
	Profile.player_name = settings_name.text.strip_edges()
	if Profile.player_name.is_empty():
		Profile.player_name = "PLAYER"
	Profile.master_volume = settings_volume.value
	Profile.fullscreen = settings_fullscreen.button_pressed
	Profile.save_settings()
	_show_home()

func _start_local_arena() -> void:
	Profile.save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _start_wlan_host() -> void:
	Wlan.local_player_name = Profile.player_name
	Profile.save_settings()
	var result: Error = Wlan.start_host()
	if result != OK:
		_set_wlan_message(Wlan.status_message)
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _join_wlan() -> void:
	_join_wlan_at(wlan_address.text)

func _join_browser_host() -> void:
	_join_wlan_at(_default_wlan_address())

func _join_wlan_at(address: String) -> void:
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		_set_wlan_message("ВКАЖІТЬ АДРЕСУ ХОСТА АБО ВІДКРИЙТЕ ЙОГО ПОСИЛАННЯ.")
		return
	Wlan.local_player_name = Profile.player_name
	var result: Error = Wlan.connect_to(clean_address)
	if result != OK:
		_set_wlan_message(Wlan.status_message)
		return
	_set_wlan_message("ПІДКЛЮЧЕННЯ…")

func _default_wlan_address() -> String:
	if OS.has_feature("web"):
		var page_host := str(JavaScriptBridge.eval("window.location.hostname", true))
		if not page_host.is_empty() and page_host != "null":
			return page_host + ":" + str(Wlan.GAME_PORT)
	return ""

func _on_wlan_connected() -> void:
	if current_screen == "wlan":
		Profile.save_settings()
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_wlan_failed(reason: String) -> void:
	if current_screen == "wlan":
		_set_wlan_message(reason)

func _set_wlan_message(message: String) -> void:
	if is_instance_valid(wlan_message):
		wlan_message.text = message

func _on_update_status_changed(message: String, retry: bool, install: bool) -> void:
	if not is_instance_valid(update_status_button) or not is_instance_valid(update_status_label):
		return
	update_status_label.text = message
	update_status_button.disabled = not retry and not install

func _on_update_status_pressed() -> void:
	if UpdateManager.can_install:
		UpdateManager.open_downloaded_update()
	elif UpdateManager.can_retry:
		UpdateManager.check_for_updates()

func _exit_game() -> void:
	get_tree().quit()
