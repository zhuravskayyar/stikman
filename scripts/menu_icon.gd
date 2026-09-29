extends Control

var kind := "play"
var tint := Color("29231d")

func _draw() -> void:
	var center := size * 0.5
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.23, size.y * 0.12), Vector2(size.x * 0.23, size.y * 0.88), Vector2(size.x * 0.83, size.y * 0.5)]), tint)
		"wlan":
			draw_arc(center + Vector2(0, 1), size.x * 0.34, PI * 1.16, PI * 1.84, 20, tint, 3.0, true)
			draw_arc(center + Vector2(0, 5), size.x * 0.22, PI * 1.18, PI * 1.82, 16, tint, 3.0, true)
			draw_circle(center + Vector2(0, 9), 3.0, tint)
			draw_circle(center + Vector2(-11, 22), 4.0, tint)
			draw_circle(center + Vector2(11, 22), 4.0, tint)
			draw_line(center + Vector2(-11, 27), center + Vector2(-11, 39), tint, 3.0, true)
			draw_line(center + Vector2(11, 27), center + Vector2(11, 39), tint, 3.0, true)
		"online":
			var radius := minf(size.x, size.y) * 0.38
			draw_arc(center, radius, 0.0, TAU, 40, tint, 3.0, true)
			draw_arc(center, radius * 0.52, -PI * 0.5, PI * 0.5, 24, tint, 2.2, true)
			draw_arc(center, radius * 0.52, PI * 0.5, PI * 1.5, 24, tint, 2.2, true)
			draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), tint, 2.2, true)
			draw_arc(center, radius * 0.82, 0.0, PI, 24, tint, 1.8, true)
			draw_arc(center, radius * 0.82, PI, TAU, 24, tint, 1.8, true)
