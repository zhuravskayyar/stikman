extends PanelContainer

var details: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f7f0df")
	paper.border_color = Color.BLACK
	paper.set_border_width_all(2)
	paper.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	paper.shadow_size = 5
	paper.content_margin_left = 15.0
	paper.content_margin_right = 15.0
	paper.content_margin_top = 9.0
	paper.content_margin_bottom = 9.0
	add_theme_stylebox_override("panel", paper)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	add_child(layout)
	var heading := Label.new()
	heading.text = "WLAN HOST"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color.BLACK)
	layout.add_child(heading)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 15)
	details.add_theme_color_override("font_color", Color.BLACK)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(details)
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()

func set_host_details(address: String, game_port: int, browser_url: String, player_count: int, player_limit: int) -> void:
	details.text = "IP ХОСТА: %s:%d   •   ГРАВЦІ %d/%d\nБРАУЗЕР: %s" % [address, game_port, player_count, player_limit, browser_url]
	visible = true
	_layout_panel()

func _layout_panel() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(620.0, maxf(240.0, viewport_size.x - 24.0))
	size = Vector2(panel_width, 104.0)
	position = Vector2((viewport_size.x - panel_width) * 0.5, 72.0)
