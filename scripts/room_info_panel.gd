extends PanelContainer

var status_button: Button
var details: Label
var _expanded := false
var _game_address := ""
var _browser_address := ""
var _player_count := 1
var _player_limit := 4

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f7f0df")
	paper.border_color = Color.BLACK
	paper.set_border_width_all(2)
	paper.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	paper.shadow_size = 4
	paper.content_margin_left = 10.0
	paper.content_margin_right = 10.0
	paper.content_margin_top = 5.0
	paper.content_margin_bottom = 5.0
	add_theme_stylebox_override("panel", paper)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	add_child(layout)
	status_button = Button.new()
	status_button.flat = true
	status_button.focus_mode = Control.FOCUS_NONE
	status_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	status_button.add_theme_font_size_override("font_size", 14)
	status_button.add_theme_color_override("font_color", Color.BLACK)
	status_button.add_theme_color_override("font_hover_color", Color("a83a2d"))
	status_button.pressed.connect(_toggle_expanded)
	layout.add_child(status_button)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 13)
	details.add_theme_color_override("font_color", Color.BLACK)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(details)
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()

func set_host_details(address: String, game_port: int, browser_url: String, player_count: int, player_limit: int) -> void:
	_game_address = "%s:%d" % [address, game_port]
	_browser_address = browser_url
	_player_count = player_count
	_player_limit = player_limit
	status_button.text = "WLAN  %d/%d   %s" % [player_count, player_limit, "▲" if _expanded else "▼"]
	details.text = "Гра: %s\nБраузер: %s" % [_game_address, _browser_address]
	visible = true
	_layout_panel()

func _toggle_expanded() -> void:
	_expanded = not _expanded
	details.visible = _expanded
	status_button.text = "WLAN  %d/%d   %s" % [_player_count, _player_limit, "▲" if _expanded else "▼"]
	_layout_panel()

func _layout_panel() -> void:
	if not is_inside_tree():
		return
	details.visible = _expanded
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := InputManager.get_safe_area_insets(viewport_size)
	var scale := InputManager.get_viewport_units_per_css_pixel(viewport_size)
	if scale <= 0.0:
		scale = 1.0
	var side_padding := 12.0 * scale
	var top := safe.y + 60.0 * scale
	var panel_width := (360.0 if _expanded else 166.0) * scale
	panel_width = minf(panel_width, viewport_size.x - safe.x - safe.z - side_padding * 2.0)
	var panel_height := (100.0 if _expanded else 48.0) * scale
	size = Vector2(panel_width, panel_height)
	position = Vector2(viewport_size.x - safe.z - side_padding - panel_width, top)
