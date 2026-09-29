extends Node2D

const Art = preload("res://scripts/art.gd")

var kind := "health"
var label := ""
var sprite: Sprite2D
var start_y := 0.0
var falling := false
var drop_velocity := Vector2.ZERO
var expires_after := 0.0

func _ready() -> void:
	start_y = position.y
	sprite = Sprite2D.new()
	sprite.texture = Art.pickup(kind)
	var scale_value := minf(32.2 / sprite.texture.get_width(), 23.8 / sprite.texture.get_height()) if kind in ["pistol", "uzi", "ak47", "shotgun", "sniper", "rocket", "saw", "shuriken"] else 0.12
	if kind == "grenade":
		scale_value = 0.12
	sprite.scale = Vector2.ONE * scale_value
	add_child(sprite)
	match kind:
		"health": label = "MEDKIT"
		"fuel": label = "FUEL"
		"ammo": label = "AMMO"
		"pistol": label = "DUAL PISTOLS"
		"uzi": label = "DUAL UZI"
		"ak47": label = "AK-47"
		"shotgun": label = "SHOTGUN"
		"sniper": label = "SNIPER"
		"rocket": label = "ROCKET"
		"grenade": label = "GRENADES 3"
	queue_redraw()

func _process(delta: float) -> void:
	if expires_after > 0.0:
		expires_after -= delta
		if expires_after <= 0.0:
			queue_free()
			return
	if falling:
		sprite.rotation += delta * 4.0
	else:
		position.y = start_y + sin(Time.get_ticks_msec() * 0.003 + start_y) * 4.0
		sprite.rotation = move_toward(sprite.rotation, 0.0, delta * 8.0)

func _physics_process(delta: float) -> void:
	if not falling:
		return
	drop_velocity.y += 850.0 * delta
	var next := global_position + drop_velocity * delta
	if drop_velocity.y >= 0.0:
		var query := PhysicsRayQueryParameters2D.create(global_position, next + Vector2(0, 7))
		var excluded: Array[RID] = []
		for attempt in range(4):
			query.exclude = excluded
			var hit := get_world_2d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				break
			var collider: Object = hit["collider"]
			if collider is StaticBody2D:
				global_position = hit["position"] + Vector2(0, -18)
				falling = false
				drop_velocity = Vector2.ZERO
				start_y = position.y
				return
			if collider is CollisionObject2D:
				excluded.append(collider.get_rid())
			else:
				break
	global_position = next

func _draw() -> void:
	draw_arc(Vector2.ZERO, 17.5, 0.0, TAU, 26, Color("66808a"), 1.1, true)
