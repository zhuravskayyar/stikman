extends Node2D

const Paper = preload("res://scripts/paper.gd")
const Player = preload("res://scripts/player.gd")
const Bot = preload("res://scripts/bot.gd")
const Drone = preload("res://scripts/drone.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Effect = preload("res://scripts/effect.gd")
const Debris = preload("res://scripts/debris.gd")
const Hud = preload("res://scripts/hud.gd")
const Hazard = preload("res://scripts/hazard.gd")
const LevelDesign = preload("res://scripts/level_design.gd")
const LevelDebug = preload("res://scripts/level_debug.gd")
const BitmapTerrain = preload("res://scripts/bitmap_terrain.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const OrientationHint = preload("res://scripts/orientation_hint.gd")
const WORLD_SIZE := LevelDesign.WORLD_SIZE

var player: CharacterBody2D
var hud: Control
var pickups: Array[Node2D] = []
var background_layer: Node2D
var terrain_layer: Node2D
var gameplay_layer: Node2D
var hazards_layer: Node2D
var decoration_layer: Node2D
var debug_layer: Node2D
var level_debug: Node2D
var kills := 0
var deaths := 0
var player_kills := 0
var input_debug_overlay: Control
var orientation_hint: CanvasLayer

func _ready() -> void:
	Sfx.set_world_root(self)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	background_layer = _make_layer("Background")
	terrain_layer = _make_layer("Terrain")
	decoration_layer = _make_layer("Decoration")
	hazards_layer = _make_layer("Hazards")
	gameplay_layer = _make_layer("Gameplay")
	debug_layer = _make_layer("Debug")
	background_layer.add_child(Paper.new())
	_build_map()
	hazards_layer.add_child(Hazard.new())
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	orientation_hint = OrientationHint.new()
	add_child(orientation_hint)
	player = Player.new()
	player.position = LevelDesign.player_spawn()
	player.world_size = WORLD_SIZE
	player.fired.connect(_on_player_fired)
	player.grenade_thrown.connect(_on_player_grenade_thrown)
	player.punched.connect(_on_player_punched)
	player.died.connect(_on_player_died)
	player.eliminated_by.connect(_on_player_eliminated_by)
	player.stats_changed.connect(hud.set_stats)
	player.zoom_changed.connect(hud.set_zoom_level)
	player.reload_changed.connect(hud.set_reload_remaining)
	gameplay_layer.add_child(player)
	hud.zoom_cycle_requested.connect(func() -> void: InputManager.pulse_action("zoom_cycle", "ui:zoom-cycle"))
	for spawn in LevelDesign.bot_spawns():
		_create_bot(spawn["position"], spawn["weapon"])
	_create_drone(LevelDesign.drone_spawn(), 320.0)
	for pickup in LevelDesign.pickup_spawns():
		_create_pickup(pickup["kind"], pickup["position"])
	level_debug = LevelDebug.new()
	level_debug.configure(player, PackedVector2Array())
	debug_layer.add_child(level_debug)
	if OS.is_debug_build():
		input_debug_overlay = preload("res://scripts/input_debug_overlay.gd").new()
		get_node("HUD").add_child(input_debug_overlay)
	_validate_level()

func _exit_tree() -> void:
	Sfx.clear_world_root()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if InputManager.is_action_just_pressed("pause") and not get_tree().paused:
		_open_pause_menu()
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if InputManager.is_action_just_pressed("pause") and not get_tree().paused:
		_open_pause_menu()
	if is_instance_valid(player):
		player.action_pointer_blocked = hud.is_action_at(get_viewport().get_mouse_position())
	if OS.is_debug_build() and InputManager.is_action_just_pressed("debug_input"):
		input_debug_overlay.visible = not input_debug_overlay.visible
	if not is_instance_valid(player) or player.dead_timer > 0.0:
		hud.prompt = ""
		hud.set_context_action_available(false)
		return
	var nearest: Node2D = null
	var distance := 82.0
	for item in pickups:
		if not is_instance_valid(item):
			continue
		var item_distance := player.global_position.distance_to(item.global_position)
		if item_distance < distance:
			nearest = item
			distance = item_distance
	hud.prompt = "E  ВЗЯТИ: " + str(nearest.get("label")) if nearest != null else ""
	hud.set_context_action_available(nearest != null)
	if InputManager.is_action_just_pressed("interact") and nearest != null:
		player.pickup(str(nearest.get("kind")))
		pickups.erase(nearest)
		nearest.queue_free()
		hud.prompt = ""
		hud.set_context_action_available(false)

func _open_pause_menu() -> void:
	var pause_menu := PauseMenu.new()
	get_node("HUD").add_child(pause_menu)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _make_layer(layer_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	add_child(layer)
	return layer

func _build_map() -> void:
	var terrain := BitmapTerrain.new()
	terrain.name = "TerrainCollision"
	terrain.carved.connect(_on_rock_carved)
	terrain_layer.add_child(terrain)

func _validate_level() -> void:
	for issue in LevelDesign.route_is_clearable():
		push_warning("LEVEL DESIGN: " + issue)

func _create_bot(at: Vector2, weapon_index: int = 2) -> void:
	var bot := Bot.new()
	bot.target = player
	bot.position = at
	bot.weapon_index = weapon_index
	bot.fired.connect(_on_robot_fired.bind(bot))
	bot.defeated.connect(_on_bot_defeated.bind(at, weapon_index))
	gameplay_layer.add_child(bot)

func _create_drone(at: Vector2, aggro_radius: float = 480.0) -> void:
	var drone := Drone.new()
	drone.target = player
	drone.position = at
	drone.aggro_radius = aggro_radius
	drone.fired.connect(_on_bot_fired.bind(drone))
	drone.defeated.connect(_on_drone_defeated.bind(at, aggro_radius))
	gameplay_layer.add_child(drone)

func _create_pickup(kind: String, at: Vector2, dropped: bool = false) -> void:
	var item := Pickup.new()
	item.kind = kind
	item.position = at
	item.falling = dropped
	if dropped:
		item.drop_velocity = Vector2(randf_range(-75.0, 75.0), -175.0)
		item.expires_after = 5.0
	pickups.append(item)
	item.tree_exiting.connect(func() -> void: pickups.erase(item))
	gameplay_layer.add_child(item)

func _on_player_fired(origin: Vector2, direction: Vector2, weapon_index: int) -> void:
	_fire_weapon(origin, direction, weapon_index, player, false)

func _on_player_grenade_thrown(origin: Vector2, direction: Vector2) -> void:
	Sfx.play_at(&"grenade_throw", origin, -15.0, 0.76, 0.08)
	_spawn_bullet(origin, direction, Player.GRENADE_DAMAGE, player, 720.0, 10000.0, Player.GRENADE_RADIUS, 760.0, "grenade", Player.GRENADE_FUSE)

func _on_player_punched(origin: Vector2, direction: Vector2) -> void:
	var query := PhysicsRayQueryParameters2D.create(origin + direction * 18.0, origin + direction * 82.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider.has_method("take_hit"):
			if collider is Node and collider.is_in_group("players"):
				collider.take_hit(hit["position"], 2, player)
			else:
				collider.take_hit(hit["position"], 2)
		_spawn_effect("impact", hit["position"], 0.13, 0.14)

func _on_bot_fired(origin: Vector2, direction: Vector2, damage: int, bot: CharacterBody2D) -> void:
	if not is_instance_valid(bot):
		return
	Sfx.play_at(&"weapon_fire", origin, -17.0, 0.92, 0.08)
	_spawn_bullet(origin, direction, damage, bot)
	_spawn_effect("muzzle", origin, 0.12, 0.09, direction.angle())

func _on_robot_fired(origin: Vector2, direction: Vector2, weapon_index: int, bot: CharacterBody2D) -> void:
	if is_instance_valid(bot):
		_fire_weapon(origin, direction, weapon_index, bot, true)

func _fire_weapon(origin: Vector2, direction: Vector2, weapon_index: int, shooter: CollisionObject2D, hostile: bool) -> void:
	var weapon: Dictionary = Player.WEAPONS[weapon_index]
	var weapon_pitch: float = [1.05, 1.2, 0.95, 0.82, 0.72, 0.68, 0.88, 1.2][weapon_index]
	Sfx.play_at(&"weapon_fire", origin, -14.0 if hostile else -11.0, weapon_pitch, 0.07)
	var pellets: int = weapon["pellets"]
	var spread: float = weapon["spread"]
	var projectile_kind: String = weapon.get("projectile_kind", "bullet")
	var tick_key := "enemy_tick_damage" if hostile else "tick_damage"
	var trap_key := "enemy_trap_damage" if hostile else "trap_damage"
	var tick_damage: int = weapon.get(tick_key, 1)
	var trap_damage: int = weapon.get(trap_key, 1)
	var shot_direction := direction
	if hostile and float(weapon["gravity"]) > 0.0:
		var target_body := shooter.get("target") as Node2D
		if is_instance_valid(target_body):
			shot_direction = _ballistic_direction(origin, target_body.global_position + Vector2(0, -10), float(weapon["speed"]), float(weapon["gravity"]))
	for pellet in range(pellets):
		var angle := randf_range(-spread, spread) if pellets == 1 else lerpf(-spread, spread, float(pellet) / float(pellets - 1))
		var damage: int = weapon["enemy_damage"] if hostile else weapon["damage"]
		_spawn_bullet(origin, shot_direction.rotated(angle), damage, shooter, weapon["speed"], weapon["range"], weapon["blast"], weapon["gravity"], projectile_kind, float(weapon.get("lifetime", 3.0)), tick_damage, float(weapon.get("tick_interval", 0.45)), float(weapon.get("trap_lifetime", 5.0)), trap_damage, float(weapon.get("trap_interval", 0.5)))
	_spawn_effect("muzzle", origin, 0.17 if weapon_index == 5 else 0.14, 0.1, shot_direction.angle())

func _ballistic_direction(origin: Vector2, target: Vector2, speed: float, gravity: float) -> Vector2:
	var offset := target - origin
	var horizontal := absf(offset.x)
	if horizontal < 0.01 or gravity <= 0.0:
		return offset.normalized()
	var speed_squared := speed * speed
	var discriminant := speed_squared * speed_squared - gravity * (gravity * horizontal * horizontal + 2.0 * offset.y * speed_squared)
	if discriminant < 0.0:
		return offset.normalized()
	var tangent := (speed_squared - sqrt(discriminant)) / (gravity * horizontal)
	var angle := atan(tangent)
	var side := signf(offset.x)
	return Vector2(side, 0.0).rotated(angle * side).normalized()

func _spawn_bullet(origin: Vector2, direction: Vector2, damage: int, shooter: CollisionObject2D, speed: float = 1250.0, max_range: float = 900.0, blast_radius: float = 0.0, gravity: float = 0.0, projectile_kind: String = "bullet", lifetime: float = 3.0, tick_damage: int = 1, tick_interval: float = 0.45, trap_lifetime: float = 5.0, trap_damage: int = 3, trap_interval: float = 0.5) -> Projectile:
	var bullet := Projectile.new()
	bullet.position = origin
	bullet.direction = direction
	bullet.projectile_kind = projectile_kind
	bullet.damage = damage
	bullet.life = lifetime
	bullet.tick_damage = tick_damage
	bullet.tick_interval = tick_interval
	bullet.trap_lifetime = trap_lifetime
	bullet.trap_damage = trap_damage
	bullet.trap_interval = trap_interval
	bullet.speed = speed
	bullet.gravity = gravity
	bullet.max_range = max_range
	bullet.blast_radius = blast_radius
	bullet.owner_body = shooter
	bullet.impacted.connect(_on_bullet_impact)
	gameplay_layer.add_child(bullet)
	return bullet

func _on_bullet_impact(at: Vector2, collider: Object, blast_radius: float, damage: int, shooter: CollisionObject2D) -> void:
	if blast_radius > 0.0:
		Sfx.play_at(&"explosion", at, -8.0, 0.88 if blast_radius > 120.0 else 1.0, 0.08)
		_explode(at, blast_radius, damage, shooter)
		_spawn_effect("explosion", at, 0.45, 0.35)
		_spawn_debris(at, 9)
		return
	if collider is CharacterBody2D:
		if collider != player:
			Sfx.play_at(&"impact", at, -13.0, 1.0, 0.08)
		_spawn_effect("impact", at, 0.15, 0.16)
	else:
		Sfx.play_at(&"terrain_impact", at, -18.0, 0.84, 0.08)
		_spawn_effect("dust", at, 0.2, 0.25)
		_spawn_debris(at, 3)

func _explode(at: Vector2, radius: float, damage: int, shooter: CollisionObject2D) -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, at)
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit_bodies: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: Object = result["collider"]
		if hit_bodies.has(body.get_instance_id()):
			continue
		hit_bodies[body.get_instance_id()] = true
		if body.has_method("excavate"):
			body.excavate(at, clampf(radius * 0.45, 28.0, 88.0))
		elif body.has_method("take_hit"):
			if body is Node and body.is_in_group("players"):
				body.take_hit(at, damage, shooter)
			else:
				body.take_hit(at, damage)

func _on_rock_carved(at: Vector2, pieces: int) -> void:
	Sfx.play_at(&"terrain_destroy", at, -14.0, 0.82, 0.08)
	Sfx.play_at(&"debris", at, -24.0, 0.68, 0.12)
	_spawn_effect("dust", at, 0.28, 0.35)
	_spawn_debris(at, mini(pieces, 10))

func _on_bot_defeated(at: Vector2, original_spawn: Vector2, weapon_index: int) -> void:
	kills += 1
	hud.kills = kills
	Sfx.play_at(&"enemy_death", at, -14.0, 0.9, 0.08)
	_spawn_effect("explosion", at, 0.33, 0.4)
	_create_pickup(Player.WEAPONS[weapon_index]["kind"], at, true)
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_inside_tree():
			_create_bot(original_spawn, weapon_index)
	)

func _on_drone_defeated(at: Vector2, original_spawn: Vector2, aggro_radius: float) -> void:
	kills += 1
	hud.kills = kills
	Sfx.play_at(&"enemy_death", at, -14.0, 0.84, 0.08)
	_spawn_effect("explosion", at, 0.36, 0.4)
	_create_pickup("uzi", at, true)
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_inside_tree():
			_create_drone(original_spawn, aggro_radius)
	)

func _on_player_died() -> void:
	deaths += 1
	hud.deaths = deaths
	Sfx.play_at(&"death", player.global_position, -8.0, 0.72, 0.08)
	_spawn_effect("explosion", player.global_position, 0.4, 0.45)

func _on_player_eliminated_by(attacker: Node) -> void:
	if attacker == player or not attacker.is_in_group("players"):
		return
	_record_player_elimination(attacker, player)

func _record_player_elimination(attacker: Object, victim: Object) -> void:
	if not attacker is Node or not victim is Node or attacker == victim:
		return
	if not attacker.is_in_group("players") or not victim.is_in_group("players"):
		return
	player_kills += 1
	hud.show_player_kill(str(attacker.get("player_name")), str(victim.get("player_name")))

func _spawn_effect(kind: String, at: Vector2, scale_value: float, lifetime: float, angle: float = 0.0) -> void:
	var effect := Effect.new()
	effect.kind = kind
	effect.position = at
	effect.size = scale_value
	effect.lifespan = lifetime
	effect.rotation = angle
	gameplay_layer.add_child(effect)

func _spawn_debris(at: Vector2, count: int) -> void:
	for i in range(count):
		var piece := Debris.new()
		piece.position = at + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
		piece.velocity = Vector2(randf_range(-180.0, 180.0), randf_range(-250.0, -80.0))
		piece.spin = randf_range(-8.0, 8.0)
		piece.radius = randf_range(3.0, 7.0)
		gameplay_layer.add_child(piece)
