extends CharacterBody2D

signal fired(origin: Vector2, direction: Vector2, weapon_index: int)
signal defeated(at: Vector2)

const Art = preload("res://scripts/art.gd")

var target: Node2D
var weapon_index := 2
var home_position := Vector2.ZERO
var health := 6
var shot_timer := 2.0
var attack_timer := 0.0
var dead_timer := 0.0
var age := 0.0
var arrival_timer := 1.2
var arrival_start := Vector2.ZERO
var preferred_avoid_side := 1.0
var aggro_radius := 360.0
var aggroed := false
var body: AnimatedSprite2D
var is_network_replica := false
var network_bot_id := 0
var network_target_position := Vector2.ZERO

func _ready() -> void:
	home_position = global_position
	arrival_start = home_position - Vector2(0, 360)
	global_position = arrival_start
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.08
	var shape := CircleShape2D.new()
	shape.radius = 14.5
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if is_network_replica:
		collision_layer = 0
		collision_mask = 0
		arrival_timer = 0.0
		network_target_position = global_position
	body = AnimatedSprite2D.new()
	body.sprite_frames = Art.robot_frames()
	body.scale = Vector2(0.10, 0.10)
	body.play("hover")
	add_child(body)

func _physics_process(delta: float) -> void:
	if is_network_replica:
		var follow_weight := minf(1.0, delta * 14.0)
		if global_position.distance_to(network_target_position) > 160.0:
			global_position = network_target_position
		else:
			global_position = global_position.lerp(network_target_position, follow_weight)
		return
	if dead_timer > 0.0:
		dead_timer -= delta
		position.y += 130.0 * delta
		if dead_timer <= 0.0:
			queue_free()
		return
	if arrival_timer > 0.0:
		arrival_timer -= delta
		velocity = _steer_toward(home_position, 280.0, 35.0)
		move_and_slide()
		body.play("hover")
		return
	age += delta
	var desired := home_position + Vector2(sin(age * 0.65) * 55.0, sin(age * 1.5) * 12.0)
	var has_target := _update_aggro()
	if has_target:
		desired = target.global_position + Vector2(0, -85)
		body.flip_h = target.global_position.x < global_position.x
	velocity = _steer_toward(desired, 105.0, 35.0)
	move_and_slide()
	_recover_from_wall()
	attack_timer = maxf(0.0, attack_timer - delta)
	if attack_timer <= 0.0 and body.animation != "hover":
		body.play("hover")
	shot_timer -= delta
	if has_target and shot_timer <= 0.0 and global_position.distance_to(target.global_position) < _attack_range() and _can_see_target():
		shot_timer = _attack_interval() + randf_range(0.0, 0.3)
		var direction := (target.global_position + Vector2(0, -10) - global_position).normalized()
		body.play("attack")
		attack_timer = 0.42
		fired.emit(global_position + direction * 47.0, direction, weapon_index)

func _steer_toward(destination: Vector2, speed: float, radius: float) -> Vector2:
	var offset := destination - global_position
	if offset.length_squared() < 16.0:
		return Vector2.ZERO
	var direct := offset.normalized()
	var look_ahead := clampf(offset.length(), 100.0, 185.0)
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

func _attack_range() -> float:
	if weapon_index == 3:
		return 360.0
	if weapon_index == 4:
		return 700.0
	return 460.0

func _attack_interval() -> float:
	match weapon_index:
		2: return 1.25
		3: return 2.8
		4: return 3.4
		5: return 3.2
	return 1.8

func _update_aggro() -> bool:
	if not is_instance_valid(target) or target.dead_timer > 0.0:
		aggroed = false
		return false
	var distance := global_position.distance_to(target.global_position)
	if aggroed:
		if distance > aggro_radius * 1.35:
			aggroed = false
	elif distance <= aggro_radius:
		aggroed = true
	return aggroed

func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position + Vector2(0, -10))
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target

func apply_network_state(state: Dictionary) -> void:
	if not is_network_replica:
		return
	network_target_position = state.get("position", global_position)
	velocity = state.get("velocity", Vector2.ZERO)
	weapon_index = int(state.get("weapon_index", weapon_index))
	health = int(state.get("health", health))
	dead_timer = float(state.get("dead_timer", dead_timer))
	if is_instance_valid(body):
		body.flip_h = bool(state.get("flip_h", body.flip_h))
		var animation_name := StringName(str(state.get("animation", "hover")))
		if body.sprite_frames.has_animation(animation_name) and body.animation != animation_name:
			body.play(animation_name)

func show_network_defeat() -> void:
	if not is_network_replica:
		return
	dead_timer = 0.95
	velocity = Vector2.ZERO
	if is_instance_valid(body):
		body.play("death")
	get_tree().create_timer(0.95).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

func take_hit(_world_point: Vector2, amount: int) -> void:
	if dead_timer > 0.0:
		return
	health -= amount
	if health <= 0:
		_die()
	else:
		body.modulate = Color("c77d79")
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			if is_instance_valid(body) and dead_timer <= 0.0:
				body.modulate = Color.WHITE
		)

func _die() -> void:
	if dead_timer > 0.0:
		return
	dead_timer = 0.95
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	body.modulate = Color.WHITE
	body.play("death")
	defeated.emit(global_position)
