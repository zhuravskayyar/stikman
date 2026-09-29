extends CharacterBody2D

signal fired(origin: Vector2, direction: Vector2, weapon_index: int)
signal grenade_thrown(origin: Vector2, direction: Vector2)
signal punched(origin: Vector2, direction: Vector2)
signal stats_changed(health: int, fuel: float, ammo: int, capacity: int, weapon_name: String, weapon_index: int, grenades: int)
signal died
signal eliminated_by(attacker: Node)
signal zoom_changed(zoom_value: float)
signal reload_changed(remaining: float)

const Art = preload("res://scripts/art.gd")
const LevelDesign = preload("res://scripts/level_design.gd")
const GlyphText = preload("res://scripts/glyph_label.gd")
const SPEED := LevelDesign.PLAYER_SPEED
const ACCELERATION := 900.0
const GRAVITY := LevelDesign.GRAVITY
const JUMP_SPEED := -LevelDesign.JUMP_SPEED
const JETPACK_FORCE := 1300.0
const ART_SCALE := 0.41
const MAX_GRENADES := 3
const MAX_HEALTH := 100
const MAX_CAMERA_ZOOM := 1.7
const GRENADE_FUSE := 3.0
const GRENADE_DAMAGE := 100
const GRENADE_RADIUS := 200.0
enum AnimationState { IDLE, RUN, JUMP, FALL, FLY, LAND, HURT, DEATH }
const ANIMATION_NAMES := [&"idle", &"run", &"jump", &"fall", &"fly_intro", &"land", &"hurt", &"death"]
const WEAPONS := [
	{"kind": "pistol", "name": "DUAL PISTOLS", "capacity": 24, "interval": 0.32, "reload": 1.25, "damage": 1, "enemy_damage": 4, "speed": 1050.0, "range": 760.0, "gravity": 260.0, "pellets": 2, "spread": 0.05, "blast": 0.0},
	{"kind": "uzi", "name": "DUAL UZI", "capacity": 48, "interval": 0.11, "reload": 1.6, "damage": 1, "enemy_damage": 3, "speed": 1250.0, "range": 850.0, "gravity": 260.0, "pellets": 2, "spread": 0.06, "blast": 0.0},
	{"kind": "ak47", "name": "AK-47", "capacity": 30, "interval": 0.13, "reload": 1.65, "damage": 3, "enemy_damage": 8, "speed": 1450.0, "range": 1100.0, "gravity": 150.0, "pellets": 1, "spread": 0.01, "blast": 0.0},
	{"kind": "shotgun", "name": "SHOTGUN", "capacity": 8, "interval": 0.76, "reload": 1.8, "damage": 2, "enemy_damage": 2, "speed": 920.0, "range": 360.0, "gravity": 680.0, "pellets": 6, "spread": 0.22, "blast": 0.0},
	{"kind": "sniper", "name": "SNIPER", "capacity": 5, "interval": 1.1, "reload": 2.2, "damage": 6, "enemy_damage": 24, "speed": 2400.0, "range": 1500.0, "gravity": 90.0, "pellets": 1, "spread": 0.0, "blast": 0.0},
	{"kind": "rocket", "name": "ROCKET", "capacity": 4, "interval": 1.15, "reload": 2.6, "damage": 8, "enemy_damage": 18, "speed": 700.0, "range": 1050.0, "gravity": 220.0, "pellets": 1, "spread": 0.0, "blast": 96.0},
	{"kind": "saw", "name": "SAW DISC", "capacity": 8, "interval": 0.62, "reload": 2.0, "damage": 2, "enemy_damage": 3, "speed": 1150.0, "range": 4600.0, "gravity": 0.0, "pellets": 1, "spread": 0.0, "blast": 0.0, "projectile_kind": "saw", "lifetime": 4.0, "tick_damage": 3, "enemy_tick_damage": 1, "tick_interval": 0.45},
	{"kind": "shuriken", "name": "SHURIKEN", "capacity": 12, "interval": 0.38, "reload": 1.5, "damage": 4, "enemy_damage": 10, "speed": 1450.0, "range": 2000.0, "gravity": 80.0, "pellets": 1, "spread": 0.0, "blast": 0.0, "projectile_kind": "shuriken", "lifetime": 4.0, "trap_lifetime": 5.0, "trap_damage": 3, "enemy_trap_damage": 4, "trap_interval": 0.5}
]

var fuel := 100.0
var health := MAX_HEALTH
var weapon_index := 0
var unlocked := [true, false, false, false, false, false, false, false]
var ammo := [24, 48, 30, 8, 5, 4, 8, 12]
var grenades := MAX_GRENADES
var cooldown := 0.0
var reload_remaining := 0.0
var aiming := Vector2.RIGHT
var thrusting := false
var spawn_position := Vector2.ZERO
var dead_timer := 0.0
var hurt_timer := 0.0
var land_timer := 0.0
var invulnerability := 0.0
var animation_state: AnimationState = AnimationState.IDLE
var previous_space := false
var was_on_floor := false
var action_pointer_blocked := false
var facing_left := false
var flight_phase := 0.0
var pack_frame := -1
var punch_cooldown := 0.0
var punch_flash := 0.0
var punch_direction := Vector2.RIGHT
var world_size := LevelDesign.WORLD_SIZE
var target_zoom := LevelDesign.DEFAULT_ZOOM
var trajectory_start := Vector2.ZERO
var trajectory_end := Vector2.ZERO
var trajectory_points := PackedVector2Array()

var body: AnimatedSprite2D
var camera: Camera2D
var weapon_pivot: Node2D
var gun: Sprite2D
var arms: Sprite2D
var pack: Sprite2D
var player_name := "PLAYER"
var name_plate: GlyphText

func _ready() -> void:
	add_to_group("players")
	var profile := get_node_or_null("/root/Profile")
	if profile != null:
		player_name = str(profile.player_name)
	spawn_position = global_position
	var shape := CapsuleShape2D.new()
	shape.radius = LevelDesign.PLAYER_WIDTH * 0.5
	shape.height = LevelDesign.PLAYER_HEIGHT
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	floor_snap_length = 7.0
	safe_margin = 0.04
	pack = Sprite2D.new()
	pack.texture = Art.jetpack(false)
	pack.scale = Vector2(42.0 * ART_SCALE / pack.texture.get_width(), 52.0 * ART_SCALE / pack.texture.get_height())
	pack.position = Vector2(-30, -10) * ART_SCALE
	pack.z_index = -1
	add_child(pack)
	body = AnimatedSprite2D.new()
	body.sprite_frames = Art.character_frames()
	body.scale = Vector2.ONE * 0.45 * ART_SCALE
	body.position = Vector2(0, -3) * ART_SCALE
	body.play("idle")
	body.animation_finished.connect(_on_body_animation_finished)
	add_child(body)
	name_plate = GlyphText.new()
	name_plate.text = player_name
	name_plate.font_size = 18.0
	name_plate.font_color = Color("211b18")
	name_plate.alignment = GlyphText.Align.CENTER
	name_plate.position = Vector2(-125.0, -61.0)
	name_plate.size = Vector2(250.0, 28.0)
	name_plate.z_index = 10
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_plate)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(0, -11) * ART_SCALE
	add_child(weapon_pivot)
	gun = Sprite2D.new()
	gun.texture = Art.weapon(0)
	gun.centered = false
	gun.position = Vector2(18, -11) * ART_SCALE
	gun.scale = Vector2.ONE * 0.18 * ART_SCALE
	weapon_pivot.add_child(gun)
	arms = Sprite2D.new()
	arms.texture = Art.region(Art.ARMS, Rect2(45, 315, 330, 115))
	arms.centered = false
	arms.position = Vector2(-6, -6) * ART_SCALE
	arms.scale = Vector2.ONE * 0.17 * ART_SCALE
	weapon_pivot.add_child(arms)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	target_zoom = maxf(target_zoom, _minimum_camera_zoom())
	camera.zoom = Vector2.ONE * target_zoom
	add_child(camera)
	camera.make_current()
	var audio_listener := AudioListener2D.new()
	camera.add_child(audio_listener)
	audio_listener.make_current()
	_emit_stats()
	zoom_changed.emit(_current_zoom_label())
	InputManager.zoom_requested.connect(_on_zoom_requested)

func _process(delta: float) -> void:
	var safe_zoom := maxf(target_zoom, _minimum_camera_zoom())
	camera.zoom = camera.zoom.lerp(Vector2.ONE * safe_zoom, minf(1.0, delta * 9.0))
	_handle_action_presses()

func _handle_action_presses() -> void:
	if InputManager.is_action_just_pressed("zoom_in"):
		set_zoom(target_zoom * 1.12)
	if InputManager.is_action_just_pressed("zoom_out"):
		set_zoom(target_zoom / 1.12)
	if InputManager.is_action_just_pressed("zoom_reset"):
		set_zoom(LevelDesign.DEFAULT_ZOOM)
	if InputManager.is_action_just_pressed("zoom_cycle"):
		cycle_zoom()
	if InputManager.is_action_just_pressed("skill_2") or InputManager.is_action_just_pressed("reload"):
		_start_reload()
	if InputManager.is_action_just_pressed("skill_1"):
		punch()
	if InputManager.is_action_just_pressed("skill_3") or InputManager.is_action_just_pressed("weapon_next"):
		select_next_weapon()
	if InputManager.is_action_just_pressed("skill_4") or InputManager.is_action_just_pressed("throw_grenade"):
		throw_grenade()
	for index in range(8):
		if InputManager.is_action_just_pressed("weapon_%d" % (index + 1)):
			_select_weapon(index)

func _on_zoom_requested(factor: float) -> void:
	set_zoom(target_zoom * factor)

func set_zoom(value: float) -> void:
	var minimum_zoom := _minimum_camera_zoom()
	target_zoom = clampf(value, minimum_zoom, maxf(MAX_CAMERA_ZOOM, minimum_zoom))
	zoom_changed.emit(_current_zoom_label())

func cycle_zoom() -> void:
	var cycle := [2.0, 4.0, 6.0, 8.0, 1.0]
	var current_index := cycle.find(_current_zoom_label())
	var next_level: float = cycle[(current_index + 1) % cycle.size()]
	set_zoom(_camera_zoom_for_level(next_level))

func _current_zoom_label() -> float:
	var nearest_level := 2.0
	var nearest_distance := absf(target_zoom - _camera_zoom_for_level(nearest_level))
	for level in [4.0, 6.0, 8.0, 1.0]:
		var distance := absf(target_zoom - _camera_zoom_for_level(level))
		if distance < nearest_distance:
			nearest_level = level
			nearest_distance = distance
	return nearest_level

func _camera_zoom_for_level(level: float) -> float:
	var minimum_zoom := _minimum_camera_zoom()
	var standard_zoom := maxf(LevelDesign.DEFAULT_ZOOM, minimum_zoom)
	match level:
		1.0:
			return maxf(1.0, minimum_zoom)
		2.0:
			return standard_zoom
		4.0:
			return lerpf(standard_zoom, minimum_zoom, 1.0 / 3.0)
		6.0:
			return lerpf(standard_zoom, minimum_zoom, 2.0 / 3.0)
		8.0:
			return minimum_zoom
	return standard_zoom

func _minimum_camera_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / world_size.x, viewport_size.y / world_size.y)

func _physics_process(delta: float) -> void:
	if dead_timer > 0.0:
		dead_timer -= delta
		if dead_timer <= 0.0:
			respawn()
		return
	var movement_input := InputManager.get_move_vector()
	velocity.x = move_toward(velocity.x, movement_input.x * SPEED, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var space := InputManager.is_action_pressed("jump") or InputManager.get_touch_move_vector().y <= -0.25
	if space and not previous_space and is_on_floor():
		velocity.y = JUMP_SPEED
		Sfx.play_at(&"jump", global_position, -15.0, 1.0, 0.08)
	thrusting = space and not is_on_floor() and fuel > 0.0
	if thrusting:
		velocity.y = maxf(velocity.y - JETPACK_FORCE * delta, -365.0)
		fuel = maxf(0.0, fuel - 39.0 * delta)
	else:
		fuel = minf(100.0, fuel + 24.0 * delta)
	previous_space = space
	move_and_slide()
	var top_limit := LevelDesign.PLAYER_HEIGHT * 0.5
	if global_position.y < top_limit:
		global_position.y = top_limit
		if velocity.y < 0.0:
			velocity.y = 0.0
	if global_position.y > world_size.y + 60.0:
		_die()
		return
	if is_on_floor() and not was_on_floor:
		land_timer = 0.44
		Sfx.play_at(&"land", global_position, -19.0, 0.78, 0.08)
	was_on_floor = is_on_floor()
	if not action_pointer_blocked:
		var aim_input := InputManager.get_aim_vector(global_position + Vector2(0, -11) * ART_SCALE)
		if aim_input.is_finite() and aim_input.length_squared() > 0.04:
			aiming = aim_input.normalized()
		elif InputManager.get_active_input_device() == "touch" and absf(movement_input.x) > 0.05:
			aiming = Vector2(signf(movement_input.x), 0.0)
		if aiming.length_squared() < 0.01:
			aiming = Vector2.RIGHT
	_update_trajectory()
	facing_left = velocity.x < -13.0 if not is_on_floor() and absf(velocity.x) > 13.0 else aiming.x < 0.0
	body.flip_h = facing_left
	pack.position.x = 30.0 * ART_SCALE if facing_left else -30.0 * ART_SCALE
	pack.flip_h = facing_left
	_update_pack(delta)
	weapon_pivot.rotation = aiming.angle()
	weapon_pivot.scale.y = -1.0 if aiming.x < 0.0 else 1.0
	cooldown = maxf(0.0, cooldown - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	land_timer = maxf(0.0, land_timer - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	punch_cooldown = maxf(0.0, punch_cooldown - delta)
	punch_flash = maxf(0.0, punch_flash - delta)
	if reload_remaining > 0.0:
		reload_remaining -= delta
		if reload_remaining <= 0.0:
			reload_remaining = 0.0
			ammo[weapon_index] = WEAPONS[weapon_index]["capacity"]
		reload_changed.emit(reload_remaining)
	if InputManager.is_action_pressed("primary_action") and not action_pointer_blocked:
		_try_fire()
	_update_animation()
	_emit_stats()
	queue_redraw()

func _update_animation() -> void:
	_set_animation_state(_resolve_animation_state())

func _resolve_animation_state() -> AnimationState:
	if dead_timer > 0.0:
		return AnimationState.DEATH
	if hurt_timer > 0.0:
		return AnimationState.HURT
	if not is_on_floor():
		if thrusting:
			return AnimationState.FLY
		return AnimationState.JUMP if velocity.y < 0.0 else AnimationState.FALL
	if land_timer > 0.0:
		return AnimationState.LAND
	return AnimationState.RUN if absf(velocity.x) > 16.0 else AnimationState.IDLE

func _set_animation_state(next: AnimationState, restart := false) -> void:
	if animation_state == next and not restart:
		return
	animation_state = next
	pack.visible = next != AnimationState.FLY
	body.play(ANIMATION_NAMES[next])

func _on_body_animation_finished() -> void:
	if animation_state == AnimationState.FLY and body.animation == &"fly_intro":
		body.play("fly")

func _update_pack(delta: float) -> void:
	flight_phase += delta
	var next_frame := (int(flight_phase * 8.0) % 2) if thrusting else -1
	if next_frame != pack_frame:
		pack_frame = next_frame
		pack.texture = Art.jetpack(thrusting, maxi(0, next_frame))
		pack.scale = Vector2(42.0 * ART_SCALE / pack.texture.get_width(), 52.0 * ART_SCALE / pack.texture.get_height())
	pack.position.y = -10.0 * ART_SCALE + (sin(flight_phase * 15.0) * 1.5 * ART_SCALE if thrusting else 0.0)
	pack.rotation = (sin(flight_phase * 10.0) * 0.04 if thrusting else 0.0)

func punch() -> void:
	var touch_direction := InputManager.consume_touch_punch_direction()
	if dead_timer > 0.0 or punch_cooldown > 0.0:
		return
	if touch_direction.length_squared() > 0.001:
		punch_direction = touch_direction.normalized()
		aiming = punch_direction
		if absf(punch_direction.x) > 0.01:
			facing_left = punch_direction.x < 0.0
	else:
		punch_direction = Vector2.LEFT if facing_left else Vector2.RIGHT
	punch_cooldown = 0.42
	punch_flash = 0.16
	Sfx.play_at(&"punch", global_position, -14.0, 0.94, 0.1)
	punched.emit(global_position + Vector2(0, -10) * ART_SCALE, punch_direction)

func throw_grenade() -> void:
	if dead_timer > 0.0 or grenades <= 0:
		return
	grenades -= 1
	grenade_thrown.emit(global_position + Vector2(0, -18) * ART_SCALE + aiming * 24.0 * ART_SCALE, aiming)
	_emit_stats()

func _try_fire() -> void:
	if cooldown > 0.0 or reload_remaining > 0.0:
		return
	if ammo[weapon_index] <= 0:
		_start_reload()
		return
	ammo[weapon_index] -= 1
	cooldown = WEAPONS[weapon_index]["interval"]
	fired.emit(_muzzle_position(), aiming, weapon_index)

func _muzzle_position() -> Vector2:
	var reach: float = [110.0, 100.0, 85.0, 72.0, 82.0, 77.0, 56.0, 68.0, 58.0][weapon_index] * ART_SCALE
	var gun_origin := global_position + Vector2(0, -11) * ART_SCALE
	var muzzle := gun_origin + aiming * reach
	var query := PhysicsRayQueryParameters2D.create(gun_origin, muzzle)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"] - aiming * 2.0 * ART_SCALE
	return muzzle

func _update_trajectory() -> void:
	if not aiming.is_finite() or aiming.is_zero_approx():
		aiming = Vector2.RIGHT
	else:
		aiming = aiming.normalized()
	var origin := _muzzle_position()
	var weapon: Dictionary = WEAPONS[weapon_index]
	var velocity := aiming * float(weapon["speed"])
	var gravity: float = weapon["gravity"]
	var max_range: float = weapon["range"]
	var position := origin
	var traveled := 0.0
	trajectory_points = PackedVector2Array([to_local(origin)])
	for _step_index in range(100):
		if traveled >= max_range:
			break
		var step_time := 0.035
		var displacement := velocity * step_time + Vector2.DOWN * (0.5 * gravity * step_time * step_time)
		var step_length := displacement.length()
		if step_length <= 0.001:
			break
		var remaining := max_range - traveled
		if step_length > remaining:
			displacement *= remaining / step_length
		var next_position := position + displacement
		var query := PhysicsRayQueryParameters2D.create(position, next_position)
		query.exclude = [get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			trajectory_points.append(to_local(hit["position"]))
			break
		position = next_position
		traveled += displacement.length()
		velocity.y += gravity * step_time
		trajectory_points.append(to_local(position))
	trajectory_start = trajectory_points[0]
	trajectory_end = trajectory_points[trajectory_points.size() - 1]

func _start_reload() -> void:
	if dead_timer <= 0.0 and reload_remaining <= 0.0 and ammo[weapon_index] < WEAPONS[weapon_index]["capacity"]:
		reload_remaining = WEAPONS[weapon_index]["reload"]
		reload_changed.emit(reload_remaining)
		Sfx.play_sfx(&"reload", -15.0, 0.9, 0.05)

func _select_weapon(index: int) -> void:
	if index < 0 or index >= WEAPONS.size() or not unlocked[index]:
		return
	var previous_weapon := weapon_index
	weapon_index = index
	reload_remaining = 0.0
	reload_changed.emit(0.0)
	gun.texture = Art.weapon(index)
	gun.position = (Vector2(18, -11) if index == 0 else Vector2(10, -15)) * ART_SCALE
	var weapon_scale: float = [0.18, 0.145, 0.16, 0.13, 0.145, 0.15, 0.105, 0.09][index] * ART_SCALE
	gun.scale = Vector2.ONE * weapon_scale
	if previous_weapon != weapon_index:
		Sfx.play_sfx(&"weapon_select", -14.0, 1.0, 0.08)
	_emit_stats()

func select_next_weapon() -> void:
	for offset in range(1, WEAPONS.size() + 1):
		var next := (weapon_index + offset) % WEAPONS.size()
		if unlocked[next]:
			_select_weapon(next)
			return

func pickup(kind: String) -> void:
	match kind:
		"health": health = mini(MAX_HEALTH, health + 45)
		"fuel": fuel = minf(100.0, fuel + 60.0)
		"grenade": grenades = MAX_GRENADES
		"ammo":
			for index in range(WEAPONS.size()):
				if unlocked[index]:
					ammo[index] = WEAPONS[index]["capacity"]
		_:
			for index in range(WEAPONS.size()):
				if WEAPONS[index]["kind"] == kind:
					unlocked[index] = true
					ammo[index] = WEAPONS[index]["capacity"]
					_select_weapon(index)
					break
	Sfx.play_at(&"pickup", global_position, -12.0, 1.0, 0.08)
	_emit_stats()

func take_hit(_world_point: Vector2, amount: int, attacker: Node = null) -> void:
	if dead_timer > 0.0 or invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	hurt_timer = 0.34
	invulnerability = 0.35
	_set_animation_state(AnimationState.HURT, true)
	if health == 0:
		if is_instance_valid(attacker) and attacker != self and attacker.is_in_group("players"):
			eliminated_by.emit(attacker)
		_die()
	else:
		Sfx.play_at(&"character_hurt", global_position, -14.0, 0.92, 0.1)
		_emit_stats()

func _die() -> void:
	if dead_timer > 0.0:
		return
	dead_timer = 1.0
	reload_remaining = 0.0
	reload_changed.emit(0.0)
	health = 0
	thrusting = false
	weapon_pivot.visible = false
	_set_animation_state(AnimationState.DEATH, true)
	died.emit()
	_emit_stats()
	queue_redraw()

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	fuel = 100.0
	health = MAX_HEALTH
	unlocked = [true, false, false, false, false, false, false, false]
	ammo = [24, 48, 30, 8, 5, 4, 8, 12]
	grenades = MAX_GRENADES
	cooldown = 0.0
	_select_weapon(0)
	previous_space = false
	was_on_floor = false
	pack_frame = -1
	invulnerability = 1.0
	weapon_pivot.visible = true
	_set_animation_state(AnimationState.IDLE, true)
	_emit_stats()

func _emit_stats() -> void:
	stats_changed.emit(health, fuel, ammo[weapon_index], WEAPONS[weapon_index]["capacity"], WEAPONS[weapon_index]["name"], weapon_index, grenades)

func _draw() -> void:
	if dead_timer <= 0.0 and not action_pointer_blocked and trajectory_points.size() > 1 and trajectory_start.distance_to(trajectory_end) > 5.0:
		draw_polyline(trajectory_points, Color("cb626d90"), 1.6, true)
		draw_arc(trajectory_end, 5.0, 0.0, TAU, 16, Color("cb626dc0"), 1.4, true)
	if thrusting and dead_timer <= 0.0 and animation_state != AnimationState.FLY:
		var t := Time.get_ticks_msec() * 0.02
		var x := pack.position.x
		var length := (24.0 + sin(t) * 7.0) * ART_SCALE
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7 * ART_SCALE, 12 * ART_SCALE), Vector2(x + 7 * ART_SCALE, 12 * ART_SCALE), Vector2(x + sin(t * 0.6) * 3.0 * ART_SCALE, 14 * ART_SCALE + length)]), Color("df7854"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4 * ART_SCALE, 13 * ART_SCALE), Vector2(x + 4 * ART_SCALE, 13 * ART_SCALE), Vector2(x, 14 * ART_SCALE + length * 0.75)]), Color("ffdc8c"))
		for i in range(3):
			var drift := fposmod(flight_phase * 70.0 + i * 13.0, 37.0) * ART_SCALE
			draw_circle(Vector2(x + sin(t + i * 2.1) * 8.0 * ART_SCALE, 21.0 * ART_SCALE + drift), 1.6 * ART_SCALE, Color("d47c60", 1.0 - drift / (43.0 * ART_SCALE)))
	if punch_flash > 0.0:
		var swing_center := Vector2(0.0, -8.0) * ART_SCALE + punch_direction * 34.0 * ART_SCALE
		var swing_angle := punch_direction.angle()
		draw_arc(swing_center, 20.0 * ART_SCALE, swing_angle - 0.9, swing_angle + 0.9, 12, Color("272231"), 2.5 * ART_SCALE, true)
