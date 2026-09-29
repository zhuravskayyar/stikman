extends Node2D

const INK := Color("303044")
const LEAF := Color("8fa98a")
const LEAF_LIGHT := Color("a9bc9e")
const WOOD := Color("b89878")
const STONE := Color("aeb9ba")

var kind := "rock_cluster"
var art_scale := 1.0

func _ready() -> void:
	if kind != "rope_bridge":
		return
	var bridge_body := StaticBody2D.new()
	var collision := CollisionPolygon2D.new()
	collision.polygon = _bridge_collision_points()
	bridge_body.add_child(collision)
	add_child(bridge_body)

func _draw() -> void:
	match kind:
		"tree": _draw_tree(false)
		"bare_tree": _draw_tree(true)
		"fence": _draw_fence()
		"rock_cluster": _draw_rocks()
		"rope_bridge": _draw_rope_bridge()

func _draw_tree(bare: bool) -> void:
	var trunk := PackedVector2Array([
		Vector2(-3, 0), Vector2(-1, -25), Vector2(-4, -48), Vector2(-17, -63),
		Vector2(-20, -78), Vector2(-17, -64), Vector2(-4, -51), Vector2(2, -40),
		Vector2(12, -58), Vector2(25, -68), Vector2(28, -82), Vector2(23, -67),
		Vector2(5, -50), Vector2(3, -28), Vector2(7, 0)
		])
	trunk = _scaled(trunk)
	draw_polyline(trunk, INK, 3.0 * art_scale, true)
	draw_line(Vector2(-1, -8) * art_scale, Vector2(1, -44) * art_scale, WOOD.darkened(0.28), 1.2 * art_scale, true)
	if bare:
		return
	for canopy in [
		Rect2(-43, -111, 47, 42), Rect2(-17, -128, 49, 45),
		Rect2(10, -112, 43, 38), Rect2(-27, -91, 55, 36)
		]:
		var bounds := Rect2(canopy.position * art_scale, canopy.size * art_scale)
		draw_colored_polygon(_ellipse(bounds, 12), LEAF_LIGHT if int(canopy.position.x) % 2 == 0 else LEAF)
		var outline := _ellipse(bounds, 12)
		outline.append(outline[0])
		draw_polyline(outline, INK, 1.7 * art_scale, true)
	for mark in [Vector2(-23, -103), Vector2(2, -117), Vector2(24, -100), Vector2(-3, -91)]:
		draw_arc(mark * art_scale, 4.0 * art_scale, 0.2, 4.3, 7, INK, 1.0 * art_scale, true)

func _draw_fence() -> void:
	for x in [-37.0, 39.0]:
		draw_polyline(_scaled(PackedVector2Array([Vector2(x - 2, 1), Vector2(x, -31), Vector2(x + 2, 2)])), INK, 2.4 * art_scale, true)
		draw_line(Vector2(x - 3, -25) * art_scale, Vector2(x + 3, -24) * art_scale, WOOD.darkened(0.22), 2.0 * art_scale, true)
	var top_rail := _scaled(PackedVector2Array([Vector2(-37, -23), Vector2(-9, -21), Vector2(12, -22), Vector2(39, -20)]))
	var lower_rail := _scaled(PackedVector2Array([Vector2(-34, -8), Vector2(-8, -7), Vector2(17, -9), Vector2(39, -7)]))
	draw_polyline(top_rail, INK, 8.0 * art_scale, true)
	draw_polyline(top_rail, WOOD, 5.0 * art_scale, true)
	draw_polyline(lower_rail, INK, 7.0 * art_scale, true)
	draw_polyline(lower_rail, WOOD, 4.4 * art_scale, true)
	for x in [-23.0, 2.0, 25.0]:
		draw_line(Vector2(x, -23) * art_scale, Vector2(x + 2, -20) * art_scale, INK, 1.0 * art_scale, true)

func _draw_rocks() -> void:
	var shapes := [
		PackedVector2Array([Vector2(-31, 0), Vector2(-27, -18), Vector2(-15, -29), Vector2(-5, -24), Vector2(1, 0)]),
		PackedVector2Array([Vector2(-8, 0), Vector2(-2, -24), Vector2(9, -36), Vector2(19, -31), Vector2(29, 0)]),
		PackedVector2Array([Vector2(17, 0), Vector2(20, -15), Vector2(31, -21), Vector2(40, 0)])
		]
	for shape in shapes:
		var scaled := _scaled(shape)
		draw_colored_polygon(scaled, STONE)
		var outline := scaled.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, INK, 2.0 * art_scale, true)
		draw_line(scaled[1] + Vector2(3, 4) * art_scale, scaled[2] + Vector2(2, 5) * art_scale, Color("687783"), 1.2 * art_scale, true)

func _draw_rope_bridge() -> void:
	var deck := PackedVector2Array()
	var upper_rope := PackedVector2Array()
	for index in range(13):
		var x := lerpf(-75.0, 75.0, float(index) / 12.0)
		var y := _bridge_y(x)
		deck.append(Vector2(x, y) * art_scale)
		upper_rope.append(Vector2(x, y - 17.0 - 9.0 * (1.0 - x * x / 5625.0)) * art_scale)
	draw_polyline(upper_rope, INK, 2.5 * art_scale, true)
	draw_polyline(deck, INK, 2.5 * art_scale, true)
	for plank_index in range(15):
		var x := -70.0 + float(plank_index) * 10.0
		var y := _bridge_y(x)
		var slope := (_bridge_y(x + 2.0) - _bridge_y(x - 2.0)) / 4.0
		var board := _rotated_rect(Vector2(x, y) * art_scale, Vector2(8.5, 7.0) * art_scale, atan(slope))
		draw_colored_polygon(board, WOOD)
		var outline := board.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, INK, 1.5 * art_scale, true)
		draw_circle(Vector2(x, y - 1.0) * art_scale, 0.8 * art_scale, Color("493f3d"))
	for endpoint in [-75.0, 75.0]:
		var post := Vector2(endpoint, _bridge_y(endpoint)) * art_scale
		var rope_end := Vector2(endpoint, _bridge_y(endpoint) - 26.0) * art_scale
		draw_line(post, rope_end, INK, 2.0 * art_scale, true)

func _bridge_y(x: float) -> float:
	return x * 0.5 + 8.0 * (1.0 - x * x / 5625.0)

func _bridge_collision_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(13):
		var x := lerpf(-75.0, 75.0, float(index) / 12.0) * art_scale
		points.append(Vector2(x, _bridge_y(x / art_scale) * art_scale))
	for index in range(12, -1, -1):
		var x := lerpf(-75.0, 75.0, float(index) / 12.0) * art_scale
		points.append(Vector2(x, (_bridge_y(x / art_scale) + 8.0) * art_scale))
	return points

func _rotated_rect(center: Vector2, size_value: Vector2, angle: float) -> PackedVector2Array:
	var half := size_value * 0.5
	var corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	])
	var output := PackedVector2Array()
	for corner in corners:
		output.append(center + corner.rotated(angle))
	return output

func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var output := PackedVector2Array()
	for point in points:
		output.append(point * art_scale)
	return output

func _ellipse(bounds: Rect2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := bounds.get_center()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		var wobble := 1.0 + 0.07 * sin(float(index) * 2.7)
		points.append(center + Vector2(cos(angle) * bounds.size.x * 0.5, sin(angle) * bounds.size.y * 0.5) * wobble)
	return points
