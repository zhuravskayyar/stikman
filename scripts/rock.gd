extends StaticBody2D

signal carved(at: Vector2, pieces: int)
signal destroyed(at: Vector2)

const Art = preload("res://scripts/art.gd")
const CELL_SIZE := 16.0
const HOLE_RADIUS := 44.0
const MISSING_KEY := Vector2i(-9999, -9999)

@export var size := Vector2(365, 244)
@export_range(1, 8) var max_health := 3
var ground := false
var destructible := true
var ground_color := Color("d6c5b4")
var protected_bottom := 24.0
var outline_override := PackedVector2Array()

var cells: Dictionary = {}
var collision_nodes_by_row: Dictionary = {}
var remaining_cells := 0
var health := 0
var grid_origin := Vector2.ZERO
var grid_columns := 0
var grid_rows := 0

func _ready() -> void:
	grid_origin = -size * 0.5
	var silhouette := _outline_points()
	grid_columns = ceili(size.x / CELL_SIZE)
	grid_rows = ceili(size.y / CELL_SIZE)
	for row in range(grid_rows):
		collision_nodes_by_row[row] = []
		for column in range(grid_columns):
			var key := Vector2i(column, row)
			var center := grid_origin + Vector2((column + 0.5) * CELL_SIZE, (row + 0.5) * CELL_SIZE)
			var cell_rect := Rect2(grid_origin + Vector2(column * CELL_SIZE, row * CELL_SIZE), Vector2.ONE * CELL_SIZE)
			var clipped := _clip_to_rect(silhouette, cell_rect)
			if clipped.size() < 3 or absf(_polygon_area(clipped)) < 2.0:
				continue
			cells[key] = {"center": center, "polygon": clipped, "hp": max_health, "alive": true}
			remaining_cells += 1
			health += max_health
	_rebuild_collision()
	queue_redraw()

func take_hit(world_point: Vector2, amount: int) -> void:
	if not destructible or remaining_cells == 0:
		return
	var key := _nearest_cell(to_local(world_point))
	if key == MISSING_KEY:
		return
	var cell: Dictionary = cells[key]
	if ground and cell["center"].y > size.y * 0.5 - protected_bottom:
		return
	var applied := mini(amount, int(cell["hp"]))
	cell["hp"] = maxi(0, int(cell["hp"]) - applied)
	health -= applied
	cells[key] = cell
	if int(cell["hp"]) == 0:
		_excavate(cell["center"])
	queue_redraw()

func has_solid_at(local_point: Vector2) -> bool:
	var key := Vector2i(floori((local_point.x - grid_origin.x) / CELL_SIZE), floori((local_point.y - grid_origin.y) / CELL_SIZE))
	return _is_solid(key) and Geometry2D.is_point_in_polygon(local_point, cells[key]["polygon"])

func _nearest_cell(point: Vector2) -> Vector2i:
	var nearest := MISSING_KEY
	var best_distance := CELL_SIZE * 1.6
	var center_column := floori((point.x - grid_origin.x) / CELL_SIZE)
	var center_row := floori((point.y - grid_origin.y) / CELL_SIZE)
	var search_radius := ceili(best_distance / CELL_SIZE) + 1
	for row in range(maxi(0, center_row - search_radius), mini(grid_rows - 1, center_row + search_radius) + 1):
		for column in range(maxi(0, center_column - search_radius), mini(grid_columns - 1, center_column + search_radius) + 1):
			var key := Vector2i(column, row)
			if not _is_solid(key):
				continue
			var center: Vector2 = cells[key]["center"]
			var distance := point.distance_to(center)
			if distance < best_distance:
				best_distance = distance
				nearest = key
	return nearest

func _excavate(center: Vector2) -> void:
	var removed := 0
	var radius_cells := ceili((HOLE_RADIUS + CELL_SIZE) / CELL_SIZE)
	var center_column := floori((center.x - grid_origin.x) / CELL_SIZE)
	var center_row := floori((center.y - grid_origin.y) / CELL_SIZE)
	var first_column := maxi(0, center_column - radius_cells)
	var last_column := mini(grid_columns - 1, center_column + radius_cells)
	var first_row := maxi(0, center_row - radius_cells)
	var last_row := mini(grid_rows - 1, center_row + radius_cells)
	for row in range(first_row, last_row + 1):
		for column in range(first_column, last_column + 1):
			var key := Vector2i(column, row)
			if not _is_solid(key):
				continue
			var cell: Dictionary = cells[key]
			var cell_center: Vector2 = cell["center"]
			if cell_center.distance_to(center) > HOLE_RADIUS:
				continue
			if ground and cell_center.y > size.y * 0.5 - protected_bottom:
				continue
			if _remove_cell(key):
				removed += 1
	removed += _remove_small_fragments_near(first_column, last_column, first_row, last_row)
	var affected_rows: Array[int] = []
	for row in range(first_row, last_row + 1):
		affected_rows.append(row)
	_rebuild_collision(affected_rows)
	carved.emit(to_global(center), removed)
	if remaining_cells == 0:
		destroyed.emit(global_position)
		queue_free()

func _remove_cell(key: Vector2i) -> bool:
	if not _is_solid(key):
		return false
	var cell: Dictionary = cells[key]
	health -= int(cell["hp"])
	cell["hp"] = 0
	cell["alive"] = false
	cells[key] = cell
	remaining_cells -= 1
	return true

func _remove_small_fragments_near(first_column: int, last_column: int, first_row: int, last_row: int) -> int:
	var visited: Dictionary = {}
	var removed := 0
	var neighbors: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for row in range(first_row, last_row + 1):
		for column in range(first_column, last_column + 1):
			var start := Vector2i(column, row)
			if not _is_solid(start) or visited.has(start):
				continue
			var pending: Array[Vector2i] = [start]
			var group: Array[Vector2i] = []
			visited[start] = true
			while not pending.is_empty() and group.size() <= 2:
				var current: Vector2i = pending.pop_back()
				group.append(current)
				for offset in neighbors:
					var adjacent: Vector2i = current + offset
					if _is_solid(adjacent) and not visited.has(adjacent):
						visited[adjacent] = true
						pending.append(adjacent)
			if group.size() <= 2 and pending.is_empty():
				for fragment in group:
					if _remove_cell(fragment):
						removed += 1
	return removed

func _is_solid(key: Vector2i) -> bool:
	return cells.has(key) and bool(cells[key]["alive"])

func _rebuild_collision(rows_to_rebuild: Array = []) -> void:
	var target_rows: Array[int] = []
	if rows_to_rebuild.is_empty():
		for row in range(grid_rows):
			target_rows.append(row)
	else:
		for row in rows_to_rebuild:
			if row >= 0 and row < grid_rows:
				target_rows.append(row)
	for row in target_rows:
		var old_nodes: Array = collision_nodes_by_row.get(row, [])
		for old in old_nodes:
			old.set_deferred("disabled", true)
			old.queue_free()
		collision_nodes_by_row[row] = []
		var column := 0
		while column < grid_columns:
			var key := Vector2i(column, row)
			if not _is_solid(key):
				column += 1
				continue
			var polygon: PackedVector2Array = cells[key]["polygon"]
			if absf(_polygon_area(polygon)) < CELL_SIZE * CELL_SIZE - 0.5:
				_add_collision_polygon(polygon, row)
				column += 1
				continue
			var start := column
			column += 1
			while column < grid_columns:
				var next_key := Vector2i(column, row)
				if not _is_solid(next_key):
					break
				var next_polygon: PackedVector2Array = cells[next_key]["polygon"]
				if absf(_polygon_area(next_polygon)) < CELL_SIZE * CELL_SIZE - 0.5:
					break
				column += 1
			var left := grid_origin.x + start * CELL_SIZE
			var right := grid_origin.x + column * CELL_SIZE
			var top := grid_origin.y + row * CELL_SIZE
			_add_collision_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, top + CELL_SIZE), Vector2(left, top + CELL_SIZE)]), row)

func _add_collision_polygon(polygon: PackedVector2Array, row: int) -> void:
	var collision := CollisionPolygon2D.new()
	collision.polygon = polygon
	var row_nodes: Array = collision_nodes_by_row.get(row, [])
	row_nodes.append(collision)
	collision_nodes_by_row[row] = row_nodes
	if Engine.is_in_physics_frame():
		call_deferred("add_child", collision)
	else:
		add_child(collision)

func _outline_points() -> PackedVector2Array:
	if not outline_override.is_empty():
		return outline_override
	var w := size.x * 0.5
	var h := size.y * 0.5
	if ground:
		return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
	return PackedVector2Array([
		Vector2(-w * 0.87, -h * 0.29), Vector2(-w * 0.64, -h * 0.65),
		Vector2(-w * 0.20, -h * 0.86), Vector2(w * 0.26, -h * 0.87),
		Vector2(w * 0.74, -h * 0.54), Vector2(w * 0.95, -h * 0.08),
		Vector2(w * 0.85, h * 0.50), Vector2(w * 0.37, h * 0.82),
		Vector2(-w * 0.12, h * 0.85), Vector2(-w * 0.42, h * 0.44),
		Vector2(-w * 0.85, h * 0.37)
	])

func _clip_to_rect(polygon: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var clipped := _clip_edge(polygon, 0, rect.position.x, true)
	clipped = _clip_edge(clipped, 0, rect.end.x, false)
	clipped = _clip_edge(clipped, 1, rect.position.y, true)
	return _clean_polygon(_clip_edge(clipped, 1, rect.end.y, false))

func _clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(point) > 0.01:
			clean.append(point)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[clean.size() - 1]) <= 0.01:
		clean.remove_at(clean.size() - 1)
	var index := 0
	while clean.size() >= 3 and index < clean.size():
		var previous := clean[(index - 1 + clean.size()) % clean.size()]
		var current := clean[index]
		var next := clean[(index + 1) % clean.size()]
		if absf((current - previous).cross(next - current)) < 0.01 and (current - previous).dot(next - current) >= 0.0:
			clean.remove_at(index)
			index = maxi(0, index - 1)
		else:
			index += 1
	return clean

func _polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5

func _clip_edge(points: PackedVector2Array, axis: int, limit: float, keep_greater: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	if points.is_empty():
		return output
	var previous := points[points.size() - 1]
	var previous_value := previous.x if axis == 0 else previous.y
	var previous_inside := previous_value >= limit if keep_greater else previous_value <= limit
	for current in points:
		var current_value := current.x if axis == 0 else current.y
		var current_inside := current_value >= limit if keep_greater else current_value <= limit
		if current_inside != previous_inside:
			var fraction := (limit - previous_value) / (current_value - previous_value)
			output.append(previous.lerp(current, fraction))
		if current_inside:
			output.append(current)
		previous = current
		previous_value = current_value
		previous_inside = current_inside
	return output

func _draw() -> void:
	var stone := ground_color if ground else Color("e9dfd0")
	for key in cells:
		if not _is_solid(key):
			continue
		var polygon: PackedVector2Array = cells[key]["polygon"]
		draw_colored_polygon(polygon, stone)
	for key in cells:
		if not _is_solid(key):
			continue
		var cell: Dictionary = cells[key]
		var center: Vector2 = cell["center"]
		var polygon: PackedVector2Array = cell["polygon"]
		for edge in range(polygon.size()):
			var start := polygon[edge]
			var end := polygon[(edge + 1) % polygon.size()]
			if not _shared_edge_is_hidden(start, end, key):
				if ground and end.x > start.x + 0.1:
					draw_line(start + Vector2(0, 1), end + Vector2(0, 1), Color("829b70"), 6.0, true)
					draw_line(start + Vector2(0, -1), end + Vector2(0, -1), Color("b7c58d"), 1.4, true)
				_draw_edge(start, end, key.x * 7 + key.y * 11 + edge)
				if ground and end.x > start.x + 0.1 and (key.x * 7 + key.y * 3) % 8 == 0:
					var tuft := (start + end) * 0.5 + Vector2(0, -3)
					draw_line(tuft, tuft + Vector2(-3, -5), Color("536d56"), 1.25, true)
					draw_line(tuft, tuft + Vector2(2, -7), Color("536d56"), 1.25, true)
		if (key.x * 13 + key.y * 19) % 11 == 0 and Geometry2D.is_point_in_polygon(center, polygon):
			draw_arc(center + Vector2(2, -1), 4.5, 0.3, 4.4, 10, Color("49464b"), 1.35, true)
		if ground and key.y > 1 and (key.x * 17 + key.y * 29) % 23 == 0 and Geometry2D.is_point_in_polygon(center, polygon):
			var hatch := center + Vector2(-2, 1)
			draw_line(hatch, hatch + Vector2(8, -5), Color("75685c88"), 1.0, true)
		if ground and key.y > 1 and key.y % 3 == 0 and key.x % 4 == 0:
			draw_line(center + Vector2(-5, 3), center + Vector2(5, 1), Color("50443a60"), 1.1, true)
		var damage := max_health - int(cell["hp"])
		if damage > 0:
			var stage := clampi(ceili(float(damage) * 3.0 / float(max_health)), 1, 3)
			draw_texture_rect(Art.damage(stage), Rect2(center - Vector2(15, 15), Vector2(30, 30)), false)

func _shared_edge_is_hidden(start: Vector2, end: Vector2, key: Vector2i) -> bool:
	var left := grid_origin.x + key.x * CELL_SIZE
	var right := left + CELL_SIZE
	var top := grid_origin.y + key.y * CELL_SIZE
	var bottom := top + CELL_SIZE
	var epsilon := 0.01
	if absf(start.x - left) < epsilon and absf(end.x - left) < epsilon:
		return _is_solid(key + Vector2i(-1, 0))
	if absf(start.x - right) < epsilon and absf(end.x - right) < epsilon:
		return _is_solid(key + Vector2i(1, 0))
	if absf(start.y - top) < epsilon and absf(end.y - top) < epsilon:
		return _is_solid(key + Vector2i(0, -1))
	if absf(start.y - bottom) < epsilon and absf(end.y - bottom) < epsilon:
		return _is_solid(key + Vector2i(0, 1))
	return false

func _draw_edge(start: Vector2, end: Vector2, seed: int) -> void:
	var middle := (start + end) * 0.5
	var wobble := float(posmod(seed, 5) - 2) * 0.7
	if absf(start.y - end.y) < 0.1:
		middle.y += wobble
	else:
		middle.x += wobble
	var ink := Color("303044")
	draw_polyline(PackedVector2Array([start, middle, end]), ink, 2.25, true)
	var offset := Vector2(0.8, -0.6) if posmod(seed, 2) == 0 else Vector2(-0.7, 0.7)
	draw_polyline(PackedVector2Array([start + offset, middle + offset * 1.4, end + offset]), Color(ink.r, ink.g, ink.b, 0.4), 0.8, true)
