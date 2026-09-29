extends Node2D

signal impacted(at: Vector2, collider: Object, blast_radius: float, damage: int, shooter: CollisionObject2D)

const Art = preload("res://scripts/art.gd")

var speed := 1250.0
var gravity := 0.0
var max_range := 900.0
var blast_radius := 0.0
var traveled := 0.0
var direction := Vector2.RIGHT
var velocity := Vector2.RIGHT * speed
var owner_body: CollisionObject2D
var damage := 1
var life := 3.0
var projectile_kind := "bullet"
var tick_damage := 1
var tick_interval := 0.45
var tick_timer := 0.45
var trap_lifetime := 5.0
var trap_damage := 3
var trap_interval := 0.5
var trap_damage_timer := 0.0
var stuck_target: Node2D
var stuck_offset := Vector2.ZERO
var stuck_surface: Node2D
var surface_offset := Vector2.ZERO
var ground_trap := false
var visual_timer := 0.0
var visual_frame := 0
var trap_shape: CircleShape2D
var sprite: Sprite2D

func _ready() -> void:
	velocity = direction.normalized() * speed
	sprite = Sprite2D.new()
	match projectile_kind:
		"grenade":
			sprite.texture = Art.grenade_frame(0)
			sprite.scale = Vector2.ONE * 0.045
		"saw":
			sprite.texture = Art.saw_blade_frame(0)
			sprite.scale = Vector2.ONE * 0.065
		"shuriken":
			sprite.texture = Art.shuriken_frame(0)
			sprite.scale = Vector2.ONE * 0.065
		_:
			sprite.texture = Art.region(Art.BULLETS, Rect2(550, 530, 520, 180)) if blast_radius > 0.0 else Art.region(Art.BULLETS, Rect2(430, 250, 440, 130))
			sprite.scale = Vector2.ONE * 0.045 if blast_radius > 0.0 else Vector2.ONE * 0.05
	if projectile_kind == "bullet":
		sprite.modulate = Color("a94839") if damage > 1 else Color("26202b")
	sprite.rotation = direction.angle()
	add_child(sprite)
	if projectile_kind == "shuriken":
		trap_shape = CircleShape2D.new()
		trap_shape.radius = 32.0

func _physics_process(delta: float) -> void:
	_animate_special(delta)
	life -= delta
	if life <= 0.0:
		if blast_radius > 0.0:
			_expire_at_range()
		else:
			queue_free()
		return
	if stuck_target != null:
		if not is_instance_valid(stuck_target):
			queue_free()
			return
		global_position = stuck_target.global_position + stuck_offset
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = tick_interval
			_apply_hit(stuck_target, global_position, tick_damage)
		return
	if ground_trap:
		if is_instance_valid(stuck_surface):
			global_position = stuck_surface.global_position + surface_offset
		_apply_trap_damage(delta)
		return
	var displacement := velocity * delta + Vector2.DOWN * (0.5 * gravity * delta * delta)
	var step_length := displacement.length()
	if step_length <= 0.0:
		queue_free()
		return
	var remaining := max_range - traveled
	if remaining <= 0.0:
		_expire_at_range()
		return
	if step_length > remaining:
		displacement *= remaining / step_length
		step_length = remaining
	var next := global_position + displacement
	var query := PhysicsRayQueryParameters2D.create(global_position, next)
	if is_instance_valid(owner_body):
		query.exclude = [owner_body.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if projectile_kind == "grenade":
			_bounce(hit["position"], hit["normal"])
		else:
			_handle_impact(hit["position"], hit["collider"])
		return
	global_position = next
	velocity.y += gravity * delta
	direction = velocity.normalized()
	if projectile_kind == "bullet" or projectile_kind == "grenade":
		sprite.rotation = direction.angle()
	traveled += step_length
	if traveled >= max_range:
		_expire_at_range()

func _bounce(point: Vector2, normal: Vector2) -> void:
	var surface_normal := normal.normalized()
	if surface_normal.is_zero_approx():
		surface_normal = -velocity.normalized()
	velocity = velocity.bounce(surface_normal) * 0.62
	if surface_normal.y < -0.5:
		velocity.x *= 0.78
	global_position = point + surface_normal * 2.0
	direction = velocity.normalized() if not velocity.is_zero_approx() else direction
	sprite.rotation = direction.angle()

func _handle_impact(point: Vector2, collider: Object) -> void:
	if projectile_kind == "saw" and collider is CharacterBody2D and collider.has_method("take_hit"):
		_apply_hit(collider, point, damage)
		stuck_target = collider
		stuck_offset = point - stuck_target.global_position
		global_position = point
		velocity = Vector2.ZERO
		tick_timer = tick_interval
		impacted.emit(point, collider, blast_radius, damage, owner_body)
		return
	if projectile_kind == "shuriken" and collider is StaticBody2D:
		ground_trap = true
		life = trap_lifetime
		global_position = point - direction * 9.0
		velocity = Vector2.ZERO
		trap_damage_timer = 0.0
		stuck_surface = collider if collider is Node2D else null
		if is_instance_valid(stuck_surface):
			surface_offset = global_position - stuck_surface.global_position
		impacted.emit(point, collider, blast_radius, damage, owner_body)
		return
	if projectile_kind == "shuriken" and collider is CharacterBody2D and collider.has_method("take_hit"):
		_apply_hit(collider, point, damage)
		impacted.emit(point, collider, blast_radius, damage, owner_body)
		queue_free()
		return
	if blast_radius <= 0.0 and collider.has_method("take_hit"):
		_apply_hit(collider, point, damage)
	impacted.emit(point, collider, blast_radius, damage, owner_body)
	queue_free()

func _apply_trap_damage(delta: float) -> void:
	trap_damage_timer -= delta
	if trap_damage_timer > 0.0:
		return
	trap_damage_timer = trap_interval
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = trap_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	var damaged: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var body: Object = result["collider"]
		if body is CharacterBody2D and body.has_method("take_hit") and not damaged.has(body.get_instance_id()):
			damaged[body.get_instance_id()] = true
			_apply_hit(body, global_position, trap_damage)

func _apply_hit(target: Object, point: Vector2, amount: int) -> void:
	if target == null or not target.has_method("take_hit"):
		return
	if target is Node and target.is_in_group("players"):
		target.take_hit(point, amount, owner_body)
	else:
		target.take_hit(point, amount)

func _animate_special(delta: float) -> void:
	if projectile_kind not in ["grenade", "saw", "shuriken"] or sprite == null:
		return
	visual_timer += delta
	if visual_timer < 0.075:
		return
	visual_timer = 0.0
	visual_frame += 1
	match projectile_kind:
		"grenade": sprite.texture = Art.grenade_frame(visual_frame)
		"saw": sprite.texture = Art.saw_blade_frame(visual_frame)
		"shuriken": sprite.texture = Art.shuriken_frame(visual_frame)

func _expire_at_range() -> void:
	if blast_radius > 0.0:
		impacted.emit(global_position, null, blast_radius, damage, owner_body)
	queue_free()
