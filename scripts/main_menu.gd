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
	UpdateManager.status_changed.connect(_on_update_status_changed)
	_show_home()
	UpdateManager.check_for_updates()
	call_deferred("_layout_screen")

func _unhandled_input(event: InputEvent) -> void:
	if InputManager.is_action_just_pressed("cancel") and current_screen != "home":
		_show_home()
		get_viewport().set_input_as_handled()

func _show_home() -> void:
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
	wlan_panel = _make_panel(Vector2(560.0, 375.0))
	screen_layer.add_child(wlan_panel)
	var heading := _make_label("CO-OP WLAN", 36.0, Color("a83a2d"), GlyphText.Align.CENTER)
	heading.position = Vector2(22.0, 20.0)
	heading.size = Vector2(516.0, 52.0)
	wlan_panel.add_child(heading)
	var instructions := _make_label("ОБИДВА ПРИСТРОЇ МАЮТЬ БУТИ В ОДНІЙ WI-FI МЕРЕЖІ", 16.0, Color("29231d"), GlyphText.Align.CENTER)
	instructions.position = Vector2(28.0, 79.0)
	instructions.size = Vector2(504.0, 54.0)
	wlan_panel.add_child(instructions)
	if OS.has_feature("web"):
		var browser_note := _make_label("У БРАУЗЕРІ МОЖНА ПІДКЛЮЧИТИСЯ ДО ХОСТА ЗА IP", 14.0, Color("a83a2d"), GlyphText.Align.CENTER)
		browser_note.position = Vector2(26.0, 125.0)
		browser_note.size = Vector2(508.0, 30.0)
		wlan_panel.add_child(browser_note)
	var address_label := _make_label("IP ХОСТА", 16.0, Color("29231d"), GlyphText.Align.LEFT)
	address_label.position = Vector2(30.0, 166.0)
	address_label.size = Vector2(170.0, 27.0)
	wlan_panel.add_child(address_label)
	wlan_address = LineEdit.new()
	wlan_address.text = _default_wlan_address()
	wlan_address.placeholder_text = "192.168.1.20:8910"
	wlan_address.position = Vector2(28.0, 195.0)
	wlan_address.size = Vector2(504.0, 48.0)
	wlan_address.add_theme_font_size_override("font_size", 20)
	wlan_address.add_theme_color_override("font_color", Color("29231d"))
	wlan_address.add_theme_stylebox_override("normal", _line_style(Color("f5ecd9")))
	wlan_address.add_theme_stylebox_override("focus", _line_style(Color("fff8e9")))
	wlan_panel.add_child(wlan_address)
	var host := _make_button("СТВОРИТИ ХОСТ", Color("a83a2d"), Color("f3e8cf"), Callable(self, "_start_wlan_host"))
	host.position = Vector2(28.0, 264.0)
	host.size = Vector2(240.0, 50.0)
	host.disabled = OS.has_feature("web")
	wlan_panel.add_child(host)
	var join := _make_button("ПІДКЛЮЧИТИСЯ", Color("29231d"), Color("f3e8cf"), Callable(self, "_join_wlan"))
	join.position = Vector2(292.0, 264.0)
	join.size = Vector2(240.0, 50.0)
	wlan_panel.add_child(join)
	wlan_message = _make_label("ХОСТ ЗАПУСКАЮТЬ У ЗАСТОСУНКУ; БРАУЗЕР ПІДКЛЮЧАЄТЬСЯ", 13.0, Color("57483a"), GlyphText.Align.CENTER)
	wlan_message.position = Vector2(28.0, 321.0)
	wlan_message.size = Vector2(504.0, 26.0)
	wlan_panel.add_child(wlan_message)
	_layout_screen()
	wlan_address.grab_focus()
	wlan_address.caret_column = wlan_address.text.length()

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
		wlan_panel.position = (viewport_size - wlan_panel.size) * 0.5

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
	Wlan.local_player_name = Profile.player_name
	var result: Error = Wlan.connect_to(wlan_address.text)
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
