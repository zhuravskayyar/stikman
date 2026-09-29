extends CharacterBody2D

signal fired(origin: Vector2, direction: Vector2, damage: int)
signal defeated(at: Vector2)

const Art = preload("res://scripts/art.gd")

var target: Node2D
var home_position := Vector2.ZERO
var health := 4
var shot_timer := 3.2
var attack_timer := 0.0
var dead_timer := 0.0
var age := 0.0
var arrival_timer := 1.35
var arrival_start := Vector2.ZERO
var preferred_avoid_side := 1.0
var aggro_radius := 250.0
var aggroed := false
var body: AnimatedSprite2D

func _ready() -> void:
	home_position = global_position
	arrival_start = home_position - Vector2(0, 420)
	global_position = arrival_start
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.08
	var shape := CircleShape2D.new()
	shape.radius = 10.5
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body = AnimatedSprite2D.new()
	body.sprite_frames = Art.drone_frames()
	body.scale = Vector2(0.09, 0.09)
	body.play("hover")
	add_child(body)

func _physics_process(delta: float) -> void:
	if dead_timer > 0.0:
		dead_timer -= delta
		position.y += 90.0 * delta
		if dead_timer <= 0.0:
			queue_free()
		return
	if arrival_timer > 0.0:
		arrival_timer -= delta
		velocity = _steer_toward(home_position, 300.0, 25.0)
		move_and_slide()
		body.play("hover")
		return
	age += delta
	var desired := home_position + Vector2(sin(age * 0.9) * 75.0, sin(age * 2.2) * 18.0)
	var has_target := _update_aggro()
	if has_target:
		desired = target.global_position + Vector2(0, -105)
		body.flip_h = target.global_position.x < global_position.x
	velocity = _steer_toward(desired, 60.0, 25.0)
	move_and_slide()
	_recover_from_wall()
	attack_timer = maxf(0.0, attack_timer - delta)
	if attack_timer <= 0.0 and body.animation != "hover":
		body.play("hover")
	shot_timer -= delta
	if has_target and shot_timer <= 0.0 and global_position.distance_to(target.global_position) < 420.0 and _can_see_target():
		shot_timer = 3.4 + randf_range(0.0, 1.0)
		var direction := (target.global_position + Vector2(0, -12) - global_position).normalized()
		body.play("attack")
		attack_timer = 0.35
		fired.emit(global_position + direction * 38.0, direction, 6)

func _update_aggro() -> bool:
	if not is_instance_valid(target) or target.dead_timer > 0.0:
		aggroed = false
		return false
	var distance := global_position.distance_to(target.global_position)
	if aggroed:
		if distance > aggro_radius * 1.15:
			aggroed = false
	else:
		if distance <= aggro_radius:
			aggroed = true
	return aggroed

func _steer_toward(destination: Vector2, speed: float, radius: float) -> Vector2:
	var offset := destination - global_position
	if offset.length_squared() < 16.0:
		return Vector2.ZERO
	var direct := offset.normalized()
	var look_ahead := clampf(offset.length(), 90.0, 205.0)
	if not _terrain_blocked(direct, look_ahead, radius):
		return direct * speed
	var candidates := [
		direct.rotated(preferred_avoid_side * 0.72),
		direct.rotated(-preferred_avoid_side * 0.72),
		direct.rotated(preferred_avoid_side * 1.25),
		direct.rotated(-preferred_avoid_side * 1.25),
		Vector2.UP,
		Vector2.DOWN
	]
	var best := Vector2.ZERO
	var best_score := -INF
	for candidate in candidates:
		if _terrain_blocked(candidate, look_ahead, radius):
			continue
		var score: float = candidate.dot(direct) * 3.0
		if score > best_score:
			best_score = score
			best = candidate
	if best == Vector2.ZERO:
		preferred_avoid_side *= -1.0
		best = direct.orthogonal() * preferred_avoid_side
	return best.normalized() * speed

func _terrain_blocked(direction: Vector2, distance: float, radius: float) -> bool:
	var side := direction.orthogonal()
	var offsets := [Vector2.ZERO, side * radius * 0.7, -side * radius * 0.7]
	for offset in offsets:
		var query := PhysicsRayQueryParameters2D.create(global_position + offset, global_position + offset + direction * distance)
		query.exclude = [get_rid()]
		query.collision_mask = 1
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit["collider"] is StaticBody2D:
			return true
	return false

func _recover_from_wall() -> void:
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		if collision.get_collider() is StaticBody2D:
			global_position += collision.get_normal() * 1.5
			preferred_avoid_side = -preferred_avoid_side

func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position + Vector2(0, -12))
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target

func take_hit(_world_point: Vector2, amount: int) -> void:
	if dead_timer > 0.0:
		return
	health -= amount
	if health <= 0:
		_die()
	else:
		body.modulate = Color("c77d79")
		get_tree().create_timer(0.16).timeout.connect(func() -> void:
			if is_instance_valid(body) and dead_timer <= 0.0:
				body.modulate = Color.WHITE
		)

func _die() -> void:
	if dead_timer > 0.0:
		return
	dead_timer = 0.9
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	body.modulate = Color.WHITE
	body.play("death")
	defeated.emit(global_position)
