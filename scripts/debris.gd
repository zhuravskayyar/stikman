extends Node2D

var velocity := Vector2.ZERO
var lifetime := 0.8
var spin := 0.0
var radius := 5.0

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	velocity.y += 500.0 * delta
	position += velocity * delta
	rotation += spin * delta
	modulate.a = minf(1.0, lifetime * 2.0)

func _draw() -> void:
	var points := PackedVector2Array([Vector2(-radius, -radius * 0.6), Vector2(radius * 0.2, -radius), Vector2(radius, 0), Vector2(radius * 0.2, radius), Vector2(-radius * 0.8, radius * 0.3)])
	draw_colored_polygon(points, Color("d8c7b2"))
	draw_polyline(points, Color("2c2522"), 2.0, true)
