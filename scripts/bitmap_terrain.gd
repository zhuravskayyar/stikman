extends StaticBody2D

signal carved(at: Vector2, pixels: int)

const VISUAL_TEXTURE: Texture2D = preload("res://assets/arena_visual.png")
const MASK_TEXTURE: Texture2D = preload("res://assets/arena_mask.png")
const CELL_SIZE := 4.0

var visual_image: Image
var mask_image: Image
var visual_texture: ImageTexture
var collision_rows: Dictionary = {}
var grid_columns := 0
var grid_rows := 0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	visual_image = VISUAL_TEXTURE.get_image()
	mask_image = MASK_TEXTURE.get_image()
	if mask_image == null or mask_image.get_size() != visual_image.get_size():
		push_error("Arena visual and collision mask must have the same dimensions")
		return
	visual_texture = ImageTexture.create_from_image(visual_image)
	var sprite := Sprite2D.new()
	sprite.name = "TerrainVisual"
	sprite.texture = visual_texture
	sprite.centered = false
	add_child(sprite)
	grid_columns = ceili(float(mask_image.get_width()) / CELL_SIZE)
	grid_rows = ceili(float(mask_image.get_height()) / CELL_SIZE)
	_rebuild_rows(0, grid_rows - 1)

func has_solid_at(local_point: Vector2) -> bool:
	if mask_image == null or local_point.x < 0.0 or local_point.y < 0.0:
		return false
	var x := floori(local_point.x)
	var y := floori(local_point.y)
	if x >= mask_image.get_width() or y >= mask_image.get_height():
		return false
	return mask_image.get_pixel(x, y).r > 0.5

func take_hit(world_point: Vector2, amount: int) -> void:
	var radius := clampf(14.0 + float(amount) * 2.2, 16.0, 55.0)
	excavate(world_point, radius)

func excavate(world_point: Vector2, radius: float) -> void:
	if mask_image == null or radius <= 0.0:
		return
	var center := to_local(world_point)
	var radius_squared := radius * radius
	var first_x := maxi(0, floori(center.x - radius))
	var last_x := mini(mask_image.get_width() - 1, ceili(center.x + radius))
	var first_y := maxi(0, floori(center.y - radius))
	var last_y := mini(mask_image.get_height() - 1, ceili(center.y + radius))
	var removed := 0
	for y in range(first_y, last_y + 1):
		for x in range(first_x, last_x + 1):
			var dx := float(x) - center.x
			var dy := float(y) - center.y
			if dx * dx + dy * dy > radius_squared:
				continue
			if mask_image.get_pixel(x, y).r > 0.5:
				mask_image.set_pixel(x, y, Color.BLACK)
				removed += 1
			if visual_image.get_pixel(x, y).a > 0.0:
				visual_image.set_pixel(x, y, Color(0, 0, 0, 0))
	if removed == 0:
		return
	visual_texture.update(visual_image)
	var first_row := maxi(0, floori((center.y - radius) / CELL_SIZE))
	var last_row := mini(grid_rows - 1, floori((center.y + radius) / CELL_SIZE))
	_rebuild_rows(first_row, last_row)
	carved.emit(to_global(center), removed)

func _rebuild_rows(first_row: int, last_row: int) -> void:
	for row in range(first_row, last_row + 1):
		var old_shapes: Array = collision_rows.get(row, [])
		for old_shape in old_shapes:
			old_shape.set_deferred("disabled", true)
			old_shape.queue_free()
		collision_rows[row] = []
		var column := 0
		while column < grid_columns:
			if not _cell_is_solid(column, row):
				column += 1
				continue
			var first_column := column
			while column < grid_columns and _cell_is_solid(column, row):
				column += 1
			var row_height := minf(CELL_SIZE, float(mask_image.get_height()) - float(row) * CELL_SIZE)
			var collision := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(float(column - first_column) * CELL_SIZE, row_height)
			collision.shape = rectangle
			collision.position = Vector2((float(first_column + column) * 0.5) * CELL_SIZE, float(row) * CELL_SIZE + row_height * 0.5)
			var row_shapes: Array = collision_rows.get(row, [])
			row_shapes.append(collision)
			collision_rows[row] = row_shapes
			if Engine.is_in_physics_frame():
				call_deferred("add_child", collision)
			else:
				add_child(collision)

func _cell_is_solid(column: int, row: int) -> bool:
	var x := mini(mask_image.get_width() - 1, roundi((float(column) + 0.5) * CELL_SIZE))
	var y := mini(mask_image.get_height() - 1, roundi((float(row) + 0.5) * CELL_SIZE))
	return mask_image.get_pixel(x, y).r > 0.5
