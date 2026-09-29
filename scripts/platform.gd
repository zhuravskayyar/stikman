extends StaticBody2D

var size := Vector2(300, 70)

func configure(new_size: Vector2) -> void:
	size = new_size
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	var left := -size.x * 0.5
	var right := size.x * 0.5
	var top := -size.y * 0.5
	var bottom := size.y * 0.5
	var points := PackedVector2Array([
		Vector2(left, top + 4), Vector2(left + size.x * 0.14, top - 1),
		Vector2(left + size.x * 0.34, top + 2), Vector2(left + size.x * 0.52, top - 2),
		Vector2(right - size.x * 0.19, top + 2), Vector2(right, top + 1),
		Vector2(right + 2, bottom - 6), Vector2(right - size.x * 0.17, bottom + 1),
		Vector2(left + size.x * 0.57, bottom - 3), Vector2(left + size.x * 0.29, bottom + 2),
		Vector2(left - 2, bottom - 5), Vector2(left, top + 4)
	])
	draw_colored_polygon(points, Color("a8c5c47a"))
	draw_polyline(points, Color("302925"), 3.3, true)
	for ratio in [0.19, 0.43, 0.72, 0.86]:
		var x: float = left + size.x * ratio
		draw_arc(Vector2(x, top + size.y * 0.55), 8.0, 0.2, 4.4, 12, Color("3a3029"), 2.0, true)
