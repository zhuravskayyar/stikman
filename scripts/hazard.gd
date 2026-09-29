extends Area2D

const LevelDesign = preload("res://scripts/level_design.gd")
const WATER_TEXTURE: Texture2D = preload("res://assets/water_surface.png")
const WORLD_SIZE := LevelDesign.WORLD_SIZE
const WATER_TOP := LevelDesign.WATER_TOP
const WATER_SIDE_EXTENSION := 480.0
const WATER_DEPTH := 360.0
const WATERLINE_RATIO := 0.28

func _water_rect() -> Rect2:
	var visual_depth := WATER_DEPTH / (1.0 - WATERLINE_RATIO)
	var size := Vector2(WORLD_SIZE.x + WATER_SIDE_EXTENSION * 2.0, visual_depth)
	return Rect2(Vector2(-WATER_SIDE_EXTENSION, WATER_TOP - visual_depth * WATERLINE_RATIO), size)

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WORLD_SIZE.x + WATER_SIDE_EXTENSION * 2.0, WATER_DEPTH)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(WORLD_SIZE.x * 0.5, WATER_TOP + WATER_DEPTH * 0.5)
	add_child(collision)
	z_index = 0
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("take_hit"):
		body.take_hit(body.global_position, 9999)
		body.velocity = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WORLD_SIZE.x + WATER_SIDE_EXTENSION * 2.0, WATER_DEPTH)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, Vector2(WORLD_SIZE.x * 0.5, WATER_TOP + WATER_DEPTH * 0.5))
	query.collision_mask = 1
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body: Object = result["collider"]
		if body is CharacterBody2D:
			_on_body_entered(body)

func _draw() -> void:
	draw_texture_rect(WATER_TEXTURE, _water_rect(), false)
