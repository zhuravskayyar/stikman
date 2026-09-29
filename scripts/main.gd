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
const RoomInfoPanel = preload("res://scripts/room_info_panel.gd")
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
var room_info_panel: Control
var networked := false
var network_players: Dictionary = {}
var network_bots: Dictionary = {}
var network_send_timer := 0.0

func _ready() -> void:
	networked = Wlan.is_active()
	if networked:
		Wlan.peer_joined.connect(_on_network_peer_joined)
		Wlan.peer_left.connect(_on_network_peer_left)
		Wlan.state_received.connect(_on_network_state_received)
		Wlan.states_received.connect(_on_network_states_received)
		Wlan.action_received.connect(_on_network_action_received)
		Wlan.status_changed.connect(_update_network_status)
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
	var room_layer := CanvasLayer.new()
	room_layer.name = "RoomInfo"
	room_layer.layer = 20
	add_child(room_layer)
	room_info_panel = RoomInfoPanel.new()
	room_layer.add_child(room_info_panel)
	orientation_hint = OrientationHint.new()
	add_child(orientation_hint)
	player = Player.new()
	player.position = LevelDesign.player_spawn()
	player.world_size = WORLD_SIZE
	player.player_name = Profile.player_name
	player.network_peer_id = Wlan.local_peer_id() if networked else 1
	player.fired.connect(_on_player_fired)
	player.grenade_thrown.connect(_on_player_grenade_thrown)
	player.punched.connect(_on_player_punched)
	player.died.connect(_on_player_died)
	player.eliminated_by.connect(_on_player_eliminated_by)
	player.stats_changed.connect(hud.set_stats)
	player.zoom_changed.connect(hud.set_zoom_level)
	player.reload_changed.connect(hud.set_reload_remaining)
	gameplay_layer.add_child(player)
	if networked:
		network_players[player.network_peer_id] = player
		for peer_id in Wlan.peer_names:
			if int(peer_id) != player.network_peer_id:
				_spawn_network_player(int(peer_id), str(Wlan.peer_names[peer_id]))
		if Wlan.is_host:
			_sync_network_bots()
		_update_network_status()
	hud.zoom_cycle_requested.connect(func() -> void: InputManager.pulse_action("zoom_cycle", "ui:zoom-cycle"))
	if not networked:
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
	if networked:
		Wlan.stop_session()

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
	if networked:
		_process_network(_delta)
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

func _sync_network_bots() -> void:
	if not networked or not Wlan.is_host:
		return
	var desired_ids: Array = network_players.keys()
	desired_ids.sort()
	for existing_id in network_bots.keys():
		if not desired_ids.has(existing_id):
			_remove_network_bot(int(existing_id), true)
	for peer_id in desired_ids:
		var bot_id := int(peer_id)
		if not network_bots.has(bot_id):
			_create_network_bot(bot_id)

func _create_network_bot(peer_id: int, forced_spawn: Vector2 = Vector2.INF, forced_weapon: int = -1) -> void:
	if not networked or not Wlan.is_host or network_bots.has(peer_id) or not network_players.has(peer_id):
		return
	var peer_ids: Array = network_players.keys()
	peer_ids.sort()
	var slot := maxi(0, peer_ids.find(peer_id))
	var spawn_entries := LevelDesign.bot_spawns()
	var spawn_positions: Array[Vector2] = []
	var weapon_indices: Array[int] = []
	for entry in spawn_entries:
		spawn_positions.append(entry["position"])
		weapon_indices.append(int(entry["weapon"]))
	spawn_positions.append(LevelDesign.drone_spawn())
	weapon_indices.append(4)
	var spawn_position: Vector2 = forced_spawn if forced_spawn != Vector2.INF else spawn_positions[slot % spawn_positions.size()]
	var weapon_index: int = forced_weapon if forced_weapon >= 0 else weapon_indices[slot % weapon_indices.size()]
	var bot := Bot.new()
	bot.network_bot_id = peer_id
	bot.target = network_players[peer_id]
	bot.position = spawn_position
	bot.weapon_index = weapon_index
	bot.fired.connect(_on_network_bot_fired.bind(bot, peer_id))
	bot.defeated.connect(_on_network_bot_defeated.bind(peer_id, spawn_position, weapon_index))
	gameplay_layer.add_child(bot)
	network_bots[peer_id] = bot

func _spawn_network_bot_replica(bot_id: int, state: Dictionary) -> void:
	if Wlan.is_host or network_bots.has(bot_id):
		return
	var bot := Bot.new()
	bot.is_network_replica = true
	bot.network_bot_id = bot_id
	bot.position = state.get("position", LevelDesign.drone_spawn())
	bot.weapon_index = int(state.get("weapon_index", 2))
	gameplay_layer.add_child(bot)
	bot.apply_network_state(state)
	network_bots[bot_id] = bot

func _remove_network_bot(bot_id: int, relay := false) -> void:
	if not network_bots.has(bot_id):
		return
	var bot: Node = network_bots[bot_id]
	network_bots.erase(bot_id)
	if is_instance_valid(bot):
		bot.queue_free()
	if relay and Wlan.is_host:
		Wlan.relay_action(1, "bot_remove", {"bot_id": bot_id})

func _bot_network_state(bot: CharacterBody2D) -> Dictionary:
	return {
		"position": bot.global_position,
		"velocity": bot.velocity,
		"weapon_index": int(bot.weapon_index),
		"health": int(bot.health),
		"dead_timer": float(bot.dead_timer),
		"flip_h": bool(bot.body.flip_h) if is_instance_valid(bot.body) else false,
		"animation": str(bot.body.animation) if is_instance_valid(bot.body) else "hover"
	}

func _on_network_bot_fired(origin: Vector2, direction: Vector2, weapon_index: int, bot: CharacterBody2D, bot_id: int) -> void:
	if not Wlan.is_host or not is_instance_valid(bot):
		return
	_fire_weapon(origin, direction, weapon_index, bot, true)
	Wlan.relay_action(1, "bot_fire", {
		"bot_id": bot_id,
		"origin": origin,
		"direction": direction,
		"weapon": weapon_index
	})

func _on_network_bot_defeated(at: Vector2, bot_id: int, original_spawn: Vector2, weapon_index: int) -> void:
	if not Wlan.is_host:
		return
	network_bots.erase(bot_id)
	Sfx.play_at(&"enemy_death", at, -14.0, 0.9, 0.08)
	_spawn_effect("explosion", at, 0.33, 0.4)
	Wlan.relay_action(1, "bot_defeated", {"bot_id": bot_id, "position": at})
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_inside_tree() and networked and Wlan.is_host and network_players.has(bot_id):
			_create_network_bot(bot_id, original_spawn, weapon_index)
	)

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
	if networked:
		var payload := {"origin": origin, "direction": direction, "weapon": weapon_index}
		if Wlan.is_host:
			_fire_weapon(origin, direction, weapon_index, player, false)
			Wlan.relay_action(player.network_peer_id, "fire", payload)
		else:
			Wlan.send_action("fire", payload)
			_spawn_visual_fire(player, origin, direction, weapon_index)
		return
	_fire_weapon(origin, direction, weapon_index, player, false)

func _on_player_grenade_thrown(origin: Vector2, direction: Vector2) -> void:
	if networked:
		var payload := {"origin": origin, "direction": direction}
		if Wlan.is_host:
			_spawn_grenade(origin, direction, player)
			Wlan.relay_action(player.network_peer_id, "grenade", payload)
		else:
			Wlan.send_action("grenade", payload)
			_spawn_visual_grenade(player, origin, direction)
		return
	_spawn_grenade(origin, direction, player)

func _spawn_grenade(origin: Vector2, direction: Vector2, shooter: CharacterBody2D) -> void:
	Sfx.play_at(&"grenade_throw", origin, -15.0, 0.76, 0.08)
	_spawn_bullet(origin, direction, Player.GRENADE_DAMAGE, shooter, 720.0, 10000.0, Player.GRENADE_RADIUS, 760.0, "grenade", Player.GRENADE_FUSE)

func _on_player_punched(origin: Vector2, direction: Vector2) -> void:
	if networked:
		var payload := {"origin": origin, "direction": direction}
		if Wlan.is_host:
			_apply_player_punch(player, origin, direction)
			Wlan.relay_action(player.network_peer_id, "punch", payload)
		else:
			Wlan.send_action("punch", payload)
		return
	_apply_player_punch(player, origin, direction)

func _apply_player_punch(puncher: CharacterBody2D, origin: Vector2, direction: Vector2) -> void:
	var query := PhysicsRayQueryParameters2D.create(origin + direction * 18.0, origin + direction * 82.0)
	query.exclude = [puncher.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider.has_method("take_hit"):
			if collider is Node and collider.is_in_group("players"):
				collider.take_hit(hit["position"], 2, puncher)
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
	if networked and Wlan.is_host:
		var shooter_id := int(shooter.get("network_peer_id")) if is_instance_valid(shooter) and shooter.is_in_group("players") else 1
		Wlan.relay_action(shooter_id, "impact", {"position": at, "blast": blast_radius, "player_hit": collider is CharacterBody2D and collider.is_in_group("players")})
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

func _on_rock_carved(at: Vector2, pieces: int, radius: float) -> void:
	if networked and Wlan.is_host:
		Wlan.relay_action(1, "terrain", {"position": at, "radius": radius})
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

func _process_network(delta: float) -> void:
	network_send_timer += delta
	if network_send_timer < 0.05:
		return
	network_send_timer = 0.0
	var local_state := _player_network_state(player)
	Wlan.publish_local_state(local_state)
	if Wlan.is_host:
		var states: Array = []
		for peer_id in network_players:
			var actor := network_players[peer_id] as CharacterBody2D
			if is_instance_valid(actor):
				states.append({"peer_id": int(peer_id), "state": _player_network_state(actor)})
		for bot_id in network_bots:
			var bot := network_bots[bot_id] as CharacterBody2D
			if is_instance_valid(bot):
				states.append({"bot_id": int(bot_id), "bot_state": _bot_network_state(bot)})
		Wlan.publish_states(states)

func _player_network_state(actor: CharacterBody2D) -> Dictionary:
	return {
		"position": actor.global_position,
		"velocity": actor.velocity,
		"aiming": actor.aiming,
		"facing_left": actor.facing_left,
		"thrusting": actor.thrusting,
		"health": actor.health,
		"dead_timer": actor.dead_timer,
		"fuel": actor.fuel,
		"ammo": actor.ammo,
		"unlocked": actor.unlocked,
		"weapon_index": actor.weapon_index,
		"grenades": actor.grenades
	}

func _spawn_network_player(peer_id: int, player_name: String) -> void:
	if network_players.has(peer_id):
		return
	var spawns: Array[Vector2] = [LevelDesign.player_spawn()]
	for spawn in LevelDesign.bot_spawns():
		spawns.append(spawn["position"])
	var slot := network_players.size() % spawns.size()
	var remote_player := Player.new()
	remote_player.player_name = player_name
	remote_player.network_peer_id = peer_id
	remote_player.is_network_replica = true
	remote_player.world_size = WORLD_SIZE
	remote_player.position = spawns[slot]
	remote_player.died.connect(_on_network_player_died.bind(remote_player))
	remote_player.eliminated_by.connect(_on_network_player_eliminated_by.bind(remote_player))
	gameplay_layer.add_child(remote_player)
	network_players[peer_id] = remote_player

func _on_network_peer_joined(peer_id: int, player_name: String) -> void:
	if peer_id == Wlan.local_peer_id():
		return
	_spawn_network_player(peer_id, player_name)
	if Wlan.is_host:
		_sync_network_bots()
	_update_network_status()

func _on_network_peer_left(peer_id: int) -> void:
	if not network_players.has(peer_id) or peer_id == Wlan.local_peer_id():
		return
	var remote_player: Node = network_players[peer_id]
	network_players.erase(peer_id)
	if is_instance_valid(remote_player):
		remote_player.queue_free()
	if Wlan.is_host:
		_sync_network_bots()
	_update_network_status()

func _on_network_state_received(peer_id: int, state: Dictionary) -> void:
	if not Wlan.is_host or peer_id == Wlan.local_peer_id():
		return
	if not network_players.has(peer_id):
		_spawn_network_player(peer_id, str(Wlan.peer_names.get(peer_id, "PLAYER")))
	var remote_player := network_players[peer_id] as CharacterBody2D
	remote_player.apply_network_state(state, false)
	if remote_player.global_position.y > WORLD_SIZE.y + 60.0 and remote_player.dead_timer <= 0.0:
		remote_player._die()

func _on_network_states_received(states: Array) -> void:
	for entry in states:
		if not entry is Dictionary:
			continue
		if entry.has("bot_id"):
			var bot_id := int(entry.get("bot_id", 0))
			if bot_id <= 0:
				continue
			var bot_state: Dictionary = entry.get("bot_state", {})
			if network_bots.has(bot_id) and not is_instance_valid(network_bots[bot_id]):
				network_bots.erase(bot_id)
			if not network_bots.has(bot_id):
				_spawn_network_bot_replica(bot_id, bot_state)
			elif is_instance_valid(network_bots[bot_id]):
				network_bots[bot_id].apply_network_state(bot_state)
			continue
		var peer_id := int(entry.get("peer_id", 0))
		if peer_id <= 0:
			continue
		var actor: CharacterBody2D
		var is_local_player := peer_id == Wlan.local_peer_id()
		if is_local_player:
			actor = player
		elif network_players.has(peer_id):
			actor = network_players[peer_id] as CharacterBody2D
		else:
			_spawn_network_player(peer_id, str(Wlan.peer_names.get(peer_id, "PLAYER")))
			actor = network_players[peer_id] as CharacterBody2D
		actor.apply_network_state(entry.get("state", {}), true, not is_local_player)
	_update_network_status()

func _on_network_action_received(peer_id: int, action: String, payload: Dictionary) -> void:
	if Wlan.is_host:
		if peer_id == Wlan.local_peer_id():
			return
		if not network_players.has(peer_id):
			return
		var actor := network_players[peer_id] as CharacterBody2D
		if actor.dead_timer > 0.0:
			return
		var direction: Vector2 = payload.get("direction", actor.aiming)
		if direction.is_zero_approx():
			direction = actor.aiming
		direction = direction.normalized()
		match action:
			"fire":
				var weapon_index := int(payload.get("weapon", 0))
				if weapon_index < 0 or weapon_index >= Player.WEAPONS.size() or not actor.unlocked[weapon_index] or actor.ammo[weapon_index] <= 0:
					return
				var origin: Vector2 = payload.get("origin", actor.global_position)
				if origin.distance_to(actor.global_position) > 110.0:
					origin = actor.global_position + Vector2(0.0, -11.0) * Player.ART_SCALE + direction * 30.0
				actor.ammo[weapon_index] -= 1
				_fire_weapon(origin, direction, weapon_index, actor, false)
				Wlan.relay_action(peer_id, action, payload)
			"grenade":
				if actor.grenades <= 0:
					return
				actor.grenades -= 1
				var grenade_origin: Vector2 = payload.get("origin", actor.global_position)
				_spawn_grenade(grenade_origin, direction, actor)
				Wlan.relay_action(peer_id, action, payload)
			"punch":
				var punch_origin: Vector2 = payload.get("origin", actor.global_position)
				_apply_player_punch(actor, punch_origin, direction)
				Wlan.relay_action(peer_id, action, payload)
		return
	if peer_id == Wlan.local_peer_id() and action not in ["bot_fire", "bot_defeated", "bot_remove"]:
		return
	if action == "bot_fire":
		var firing_bot_id := int(payload.get("bot_id", 0))
		var firing_bot: CharacterBody2D = network_bots.get(firing_bot_id) as CharacterBody2D
		if is_instance_valid(firing_bot):
			var bot_origin: Vector2 = payload.get("origin", firing_bot.global_position)
			var bot_direction: Vector2 = payload.get("direction", Vector2.RIGHT).normalized()
			_spawn_visual_fire(firing_bot, bot_origin, bot_direction, int(payload.get("weapon", 2)))
		return
	if action == "bot_defeated":
		var defeated_bot_id := int(payload.get("bot_id", 0))
		var defeated_bot: CharacterBody2D = network_bots.get(defeated_bot_id) as CharacterBody2D
		if is_instance_valid(defeated_bot):
			defeated_bot.show_network_defeat()
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				if network_bots.get(defeated_bot_id) == defeated_bot:
					network_bots.erase(defeated_bot_id)
					if is_instance_valid(defeated_bot):
						defeated_bot.queue_free()
			)
		_spawn_effect("explosion", payload.get("position", Vector2.ZERO), 0.33, 0.4)
		return
	if action == "bot_remove":
		_remove_network_bot(int(payload.get("bot_id", 0)))
		return
	var remote_player: CharacterBody2D = network_players.get(peer_id) as CharacterBody2D
	if action in ["fire", "grenade"]:
		if not is_instance_valid(remote_player):
			return
		var origin: Vector2 = payload.get("origin", remote_player.global_position)
		var direction: Vector2 = payload.get("direction", remote_player.aiming).normalized()
		if action == "fire":
			_spawn_visual_fire(remote_player, origin, direction, int(payload.get("weapon", 0)))
		else:
			_spawn_visual_grenade(remote_player, origin, direction)
	elif action == "punch" and is_instance_valid(remote_player):
		remote_player.show_network_punch(payload.get("direction", Vector2.RIGHT))
	elif action == "terrain":
		var terrain := get_node_or_null("Terrain/TerrainCollision")
		if terrain != null:
			terrain.excavate(payload.get("position", Vector2.ZERO), float(payload.get("radius", 0.0)))
	elif action == "impact":
		var at: Vector2 = payload.get("position", Vector2.ZERO)
		if float(payload.get("blast", 0.0)) > 0.0:
			_spawn_effect("explosion", at, 0.45, 0.35)
			_spawn_debris(at, 6)
		else:
			_spawn_effect("impact" if bool(payload.get("player_hit", false)) else "dust", at, 0.16, 0.2)

func _spawn_visual_fire(shooter: CharacterBody2D, origin: Vector2, direction: Vector2, weapon_index: int) -> void:
	if weapon_index < 0 or weapon_index >= Player.WEAPONS.size():
		return
	var weapon: Dictionary = Player.WEAPONS[weapon_index]
	var pellets: int = weapon["pellets"]
	var spread: float = weapon["spread"]
	for pellet in range(pellets):
		var angle := randf_range(-spread, spread) if pellets == 1 else lerpf(-spread, spread, float(pellet) / float(pellets - 1))
		var projectile := Projectile.new()
		projectile.position = origin
		projectile.direction = direction.rotated(angle)
		projectile.speed = float(weapon["speed"])
		projectile.gravity = float(weapon["gravity"])
		projectile.max_range = float(weapon["range"])
		projectile.life = minf(float(weapon.get("lifetime", 3.0)), float(weapon["range"]) / maxf(1.0, float(weapon["speed"])))
		projectile.projectile_kind = str(weapon.get("projectile_kind", "bullet"))
		projectile.owner_body = shooter
		projectile.visual_only = true
		gameplay_layer.add_child(projectile)
	_spawn_effect("muzzle", origin, 0.14, 0.1, direction.angle())

func _spawn_visual_grenade(shooter: CharacterBody2D, origin: Vector2, direction: Vector2) -> void:
	var projectile := Projectile.new()
	projectile.position = origin
	projectile.direction = direction
	projectile.speed = 720.0
	projectile.gravity = 760.0
	projectile.max_range = 10000.0
	projectile.life = Player.GRENADE_FUSE
	projectile.projectile_kind = "grenade"
	projectile.owner_body = shooter
	projectile.visual_only = true
	gameplay_layer.add_child(projectile)

func _on_network_player_died(actor: CharacterBody2D) -> void:
	if Wlan.is_host:
		Wlan.relay_action(actor.network_peer_id, "impact", {"position": actor.global_position, "blast": 0.0, "player_hit": true})

func _on_network_player_eliminated_by(attacker: Node, victim: Node) -> void:
	_record_player_elimination(attacker, victim)

func _update_network_status() -> void:
	if not networked or not is_instance_valid(room_info_panel):
		return
	if not Wlan.is_host:
		room_info_panel.visible = false
		return
	var addresses := Wlan.local_addresses()
	var address := addresses[0] if not addresses.is_empty() else "IP-ПРИСТРОЮ"
	room_info_panel.set_host_details(address, Wlan.GAME_PORT, Wlan.browser_url(), Wlan.peer_names.size(), Wlan.MAX_PLAYERS)
