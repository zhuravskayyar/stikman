extends SceneTree

const LevelDesign = preload("res://scripts/level_design.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var avatar = arena.player
	avatar.invulnerability = 999.0
	if avatar.health != 100 or avatar.weapon_index != 0 or arena.hud.weapon_button == null:
		_fail("Player or equipped-weapon HUD did not spawn")
		return
	if arena.hud.weapon_button.stretch_mode != TextureButton.STRETCH_KEEP_ASPECT_CENTERED:
		_fail("HUD weapon icon is stretched instead of keeping its aspect ratio")
		return
	var badge = arena.hud.grenade_count_panel
	if badge.position.x < 0.0 or badge.position.y < 0.0 or badge.position.x + badge.size.x > arena.hud.grenade_button.size.x or badge.position.y + badge.size.y > arena.hud.grenade_button.size.y:
		_fail("Grenade counter badge is outside its action sticker")
		return
	if not arena.hud.grenade_button.size.is_equal_approx(arena.hud.jet_button.size) or not arena.hud.jet_button.size.is_equal_approx(arena.hud.punch_button.size):
		_fail("Action stickers are not aligned at matching sizes")
		return
	var icon_buttons = [arena.hud.grenade_button, arena.hud.jet_button, arena.hud.punch_button]
	var action_icons = [arena.hud.grenade_icon, arena.hud.jet_icon, arena.hud.punch_icon]
	for index in range(action_icons.size()):
		var icon: TextureRect = action_icons[index]
		if icon.texture == null or icon.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or icon.size.x > icon_buttons[index].size.x * 0.58:
			_fail("Action icon is missing, distorted, or too large for its round backing")
			return
	if not LevelDesign.route_is_clearable().is_empty():
		_fail("Authored arena failed route validation: " + str(LevelDesign.route_is_clearable()))
		return
	var ordered_layers := ["Background", "Terrain", "Decoration", "Hazards", "Gameplay", "Debug"]
	var previous_layer_index := -1
	for layer_name in ordered_layers:
		var layer_index: int = arena.get_node(layer_name).get_index()
		if layer_index <= previous_layer_index:
			_fail("Arena layers are missing or drawn in the wrong order: " + str(_child_names(arena)))
			return
		previous_layer_index = layer_index
	var platform_count := 0
	for platform in LevelDesign.platforms():
		if platform.get("purpose", "").is_empty():
			_fail("A platform has no gameplay purpose")
			return
		platform_count += 1
	if platform_count < 4 or platform_count > 7:
		_fail("Arena does not have the intended number of authored platforms")
		return
	var debug_overlay = arena.level_debug
	debug_overlay._unhandled_input(_f3_event())
	if not debug_overlay.enabled:
		_fail("F3 did not enable the level debug overlay")
		return
	debug_overlay._unhandled_input(_f3_event())
	var robot_count := 0
	var drone_count := 0
	var robot = null
	var drone = null
	for child in _all_nodes(arena):
		if child.get_script() == null:
			continue
		match child.get_script().resource_path:
			"res://scripts/bot.gd":
				robot_count += 1
				if robot == null:
					robot = child
			"res://scripts/drone.gd":
				drone_count += 1
				if drone == null:
					drone = child
	if robot_count != 3 or drone_count != 1 or robot.body.sprite_frames.get_frame_count("hover") != 4:
		_fail("Three animated robot enemies and one drone did not spawn")
		return
	if robot.global_position.y >= robot.home_position.y - 100.0 or drone.global_position.y >= drone.home_position.y - 100.0:
		_fail("Enemies did not enter the arena from above")
		return
	for child in _all_nodes(arena):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/bot.gd" and _terrain_at(arena, child.home_position) != null:
			_fail("A robot spawn is embedded in solid terrain")
			return
	if _terrain_at(arena, drone.home_position) != null:
		_fail("The drone spawn is embedded in solid terrain")
		return
	var engaged_drones := 0
	for child in _all_nodes(arena):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/drone.gd" and child.aggroed:
			engaged_drones += 1
	if engaged_drones > 1:
		_fail("All drones entered aggro at the same time")
		return
	var terrain = _terrain_at(arena, Vector2(500, 340))
	var hazard = null
	for child in _all_nodes(arena):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/hazard.gd":
			hazard = child
			break
	if terrain == null or terrain.get_script().resource_path != "res://scripts/bitmap_terrain.gd" or hazard == null:
		_fail("Bitmap terrain or water hazard did not spawn")
		return
	var authored_specials: Dictionary = {}
	for item in arena.pickups:
		if not is_instance_valid(item) or item.falling:
			continue
		if item.kind in ["uzi", "ak47", "shotgun", "rocket"]:
			_fail("An old weapon pickup spawned on the map without an enemy drop")
			return
		if item.kind in ["grenade", "saw", "shuriken"]:
			authored_specials[item.kind] = true
	for kind in ["grenade", "saw", "shuriken"]:
		if not authored_specials.has(kind):
			_fail("A new weapon is missing its authored map pickup: " + kind)
			return
	for opening in [Vector2(700, 200), Vector2(780, 150), Vector2(1100, 200), Vector2(1150, 200)]:
		if _terrain_at(arena, opening) != null:
			_fail("An intended open combat lane is blocked: " + str(opening))
			return
	var carve_point := Vector2(500, 340)
	if terrain == null or not terrain.has_solid_at(terrain.to_local(carve_point)):
		_fail("The west island has no collision at its marked top")
		return
	terrain.take_hit(carve_point, 2)
	await physics_frame
	await physics_frame
	var point_query := PhysicsPointQueryParameters2D.new()
	point_query.position = carve_point
	for overlap in arena.get_world_2d().direct_space_state.intersect_point(point_query):
		if overlap["collider"] == terrain:
			_fail("Carved bitmap point still has collision")
			return
	var weapon_kinds := ["uzi", "ak47", "shotgun", "sniper", "rocket"]
	for index in range(weapon_kinds.size()):
		avatar.pickup(weapon_kinds[index])
		if avatar.weapon_index != index + 1 or not avatar.unlocked[index + 1] or arena.hud.weapon_index != index + 1:
			_fail("Weapon pickup or HUD icon did not update: " + weapon_kinds[index])
			return
	avatar.grenades = 0
	avatar.pickup("grenade")
	if avatar.grenades != avatar.MAX_GRENADES:
		_fail("Grenade pickup did not refill the grenade counter")
		return
	for special_index in range(2):
		var kind: String = ["saw", "shuriken"][special_index]
		avatar.pickup(kind)
		var special_weapon_index := special_index + 6
		if avatar.weapon_index != special_weapon_index or not avatar.unlocked[special_weapon_index] or arena.hud.weapon_index != special_weapon_index:
			_fail("Special weapon pickup or HUD icon did not update: " + kind)
			return
	avatar._select_weapon(2)
	arena.hud.weapon_button.pressed.emit()
	avatar._handle_action_presses()
	if avatar.weapon_index != 3:
		_fail("HUD weapon cycling did not select the next unlocked gun")
		return
	for weapon_index in range(avatar.WEAPONS.size()):
		avatar._select_weapon(weapon_index)
		avatar.cooldown = 0.0
		avatar.reload_remaining = 0.0
		avatar.aiming = Vector2.RIGHT
		var before_ammo: int = avatar.ammo[weapon_index]
		var before_shots := _projectile_count(arena)
		avatar._try_fire()
		if avatar.ammo[weapon_index] != before_ammo - 1 or _projectile_count(arena) != before_shots + int(avatar.WEAPONS[weapon_index]["pellets"]):
			_fail("Weapon fire failed: " + avatar.WEAPONS[weapon_index]["kind"])
			return
		var newest_projectile = _newest_projectile(arena)
		var expected_mode: String = avatar.WEAPONS[weapon_index].get("projectile_kind", "bullet")
		if newest_projectile == null or newest_projectile.projectile_kind != expected_mode:
			_fail("Weapon spawned the wrong projectile mode: " + avatar.WEAPONS[weapon_index]["kind"])
			return
		var projectile_width: float = float(newest_projectile.sprite.texture.get_width()) * absf(newest_projectile.sprite.scale.x)
		var projectile_height: float = float(newest_projectile.sprite.texture.get_height()) * absf(newest_projectile.sprite.scale.y)
		var robot_width: float = float(robot.body.sprite_frames.get_frame_texture("hover", 0).get_width()) * robot.body.scale.x
		if maxf(projectile_width, projectile_height) >= robot_width:
			_fail("Projectile is not smaller than a robot: " + avatar.WEAPONS[weapon_index]["kind"])
			return
	var before_pellets := _projectile_count(arena)
	arena._fire_weapon(Vector2(190, 400), Vector2.RIGHT, 3, avatar, false)
	if _projectile_count(arena) != before_pellets + 6:
		_fail("Shotgun did not fire six pellets")
		return
	avatar._select_weapon(5)
	avatar.cooldown = 0.0
	var rocket_ammo: int = avatar.ammo[5]
	avatar._try_fire()
	if avatar.ammo[5] != rocket_ammo - 1:
		_fail("Rocket launcher did not consume ammo")
		return
	var rocket_found := false
	for child in _all_nodes(arena):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/projectile.gd" and child.blast_radius > 0.0:
			if child.damage < robot.health or child.blast_radius != 96.0:
				_fail("Rocket blast damage or radius is lower than intended")
				return
			rocket_found = true
			break
	if not rocket_found:
		_fail("Rocket projectile was not created")
		return
	var blast_terrain = _terrain_at(arena, Vector2(1420, 790))
	if blast_terrain == null:
		_fail("Blast test area is missing from the bitmap terrain")
		return
	var blast_point := Vector2(1420, 790)
	arena._spawn_bullet(Vector2(1420, 760), Vector2.DOWN, 3, avatar, 720.0, 120.0, 88.0)
	await create_timer(0.25).timeout
	if blast_terrain.has_solid_at(blast_terrain.to_local(blast_point)):
		_fail("Rocket blast did not cut a matching visual and collision hole")
		return
	avatar.set_physics_process(false)
	robot.global_position = Vector2(2200, 400)
	robot.home_position = robot.global_position
	robot.arrival_timer = 0.0
	avatar.global_position = Vector2(2200, 300)
	await physics_frame
	await physics_frame
	if not robot._can_see_target():
		_fail("Robot cannot see the player in an open corridor")
		return
	robot.set_physics_process(false)
	var robot_health_before_saw: int = robot.health
	var saw_projectile = arena._spawn_bullet(Vector2(2140, 400), Vector2.RIGHT, 2, avatar, 1200.0, 500.0, 0.0, 0.0, "saw", 4.0, 2, 0.4)
	await create_timer(0.6).timeout
	if not is_instance_valid(saw_projectile) or saw_projectile.stuck_target != robot or saw_projectile.life >= 3.5:
		_fail("Saw disc did not stick to the enemy for its remaining flight time")
		return
	if robot.health > robot_health_before_saw - 3:
		_fail("Saw disc did not keep damaging the enemy while attached")
		return
	robot.set_physics_process(true)
	var robot_shots: Array[Vector2] = []
	robot.fired.connect(func(origin: Vector2, _direction: Vector2, _weapon: int) -> void: robot_shots.append(origin))
	robot.shot_timer = 0.0
	await physics_frame
	await physics_frame
	if robot_shots.is_empty():
		_fail("Robot did not fire")
		return
	robot.set_physics_process(false)
	robot.global_position = Vector2(500, 320)
	var kills_before_robot: int = arena.kills
	robot.take_hit(robot.global_position, robot.health)
	if arena.kills != kills_before_robot + 1:
		_fail("Robot defeat did not update score")
		return
	var robot_drop = _falling_pickup(arena, "ak47")
	if robot_drop == null:
		_fail("Robot did not drop its SMG")
		return
	if robot_drop.expires_after < 4.5 or robot_drop.expires_after > 5.0:
		_fail("Enemy weapon drop does not start with a five second lifetime")
		return
	var drop_wait := 0.0
	while is_instance_valid(robot_drop) and robot_drop.falling and drop_wait < 1.8:
		await create_timer(0.1).timeout
		drop_wait += 0.1
	if not is_instance_valid(robot_drop) or robot_drop.falling:
		var drop_state := "freed"
		if is_instance_valid(robot_drop):
			drop_state = "falling=%s at %s" % [str(robot_drop.falling), str(robot_drop.global_position)]
		_fail("Dropped weapon did not settle on terrain (" + drop_state + ")")
		return
	await create_timer(maxf(0.0, 5.2 - drop_wait)).timeout
	if is_instance_valid(robot_drop):
		_fail("Enemy weapon drop did not disappear after five seconds")
		return
	drone.global_position = Vector2(900, 60)
	drone.home_position = drone.global_position
	drone.arrival_timer = 0.0
	avatar.global_position = drone.global_position + Vector2(120, -10)
	await physics_frame
	await physics_frame
	if not drone._can_see_target():
		_fail("Drone could not target player in open air")
		return
	var kills_before_drone: int = arena.kills
	drone.take_hit(drone.global_position, drone.health)
	if arena.kills != kills_before_drone + 1:
		_fail("Drone defeat did not update score")
		return
	if _falling_pickup(arena, "uzi") == null:
		_fail("Drone defeat did not drop its weapon")
		return
	var shuriken_trap = arena._spawn_bullet(Vector2(900, 620), Vector2.DOWN, 4, avatar, 1000.0, 800.0, 0.0, 0.0, "shuriken", 4.0, 1, 0.45, 5.0, 3, 0.5)
	var trap_wait := 0.0
	while is_instance_valid(shuriken_trap) and not shuriken_trap.ground_trap and trap_wait < 1.0:
		await create_timer(0.05).timeout
		trap_wait += 0.05
	if not is_instance_valid(shuriken_trap) or not shuriken_trap.ground_trap or shuriken_trap.life < 4.5:
		_fail("Shuriken did not lodge in the ground for five seconds")
		return
	avatar.global_position = shuriken_trap.global_position - Vector2(0, 24)
	avatar.velocity = Vector2.ZERO
	avatar.health = 100
	avatar.invulnerability = 0.0
	await create_timer(0.55).timeout
	if avatar.health >= 100:
		_fail("Stepping on the shuriken trap did not cause damage")
		return
	avatar.set_physics_process(true)
	avatar.health = 100
	avatar.global_position = Vector2(180, 360)
	avatar.set_zoom(0.1)
	if not is_equal_approx(avatar.target_zoom, avatar._minimum_camera_zoom()):
		_fail("Minimum zoom was not clamped")
		return
	avatar.set_zoom(3.0)
	if not is_equal_approx(avatar.target_zoom, 1.7):
		_fail("Maximum zoom was not clamped")
		return
	avatar.set_zoom(1.0)
	avatar.global_position = Vector2(700, 70)
	avatar.aiming = Vector2(1.0, 0.55).normalized()
	avatar._update_trajectory()
	var aim_start_world: Vector2 = avatar.to_global(avatar.trajectory_start)
	var aim_end_world: Vector2 = avatar.to_global(avatar.trajectory_end)
	if aim_end_world.x <= aim_start_world.x + 100.0 or aim_end_world.x > 1100.0 or aim_end_world.y <= aim_start_world.y:
		_fail("Aim line did not stop at terrain")
		return
	avatar.global_position = Vector2(800, 100)
	avatar.hurt_timer = 0.0
	avatar.velocity = Vector2(-300, -80)
	root.get_node("InputManager").press_action("jump", "test:jetpack")
	avatar.previous_space = true
	await physics_frame
	await physics_frame
	await physics_frame
	if not avatar.body.flip_h or avatar.pack.position.x <= 0.0 or avatar.animation_state != avatar.AnimationState.FLY:
		_fail("Flying left did not face left")
		return
	root.get_node("InputManager").release_action("jump", "test:jetpack")
	var drops_before_death: int = arena.pickups.size()
	avatar.invulnerability = 0.0
	avatar.take_hit(avatar.global_position, 100)
	if avatar.dead_timer <= 0.0 or arena.pickups.size() != drops_before_death:
		_fail("Player death created a weapon drop")
		return
	await create_timer(1.1).timeout
	if avatar.health != 100 or avatar.dead_timer > 0.0 or avatar.weapon_index != 0 or avatar.unlocked[5] or avatar.ammo[0] != avatar.WEAPONS[0]["capacity"] or arena.hud.weapon_index != 0:
		_fail("Respawn did not restore the pistol and its HUD icon: hp=%d dead=%.2f weapon=%d unlocked=%s ammo=%d hud=%d" % [avatar.health, avatar.dead_timer, avatar.weapon_index, str(avatar.unlocked[5]), avatar.ammo[0], arena.hud.weapon_index])
		return
	avatar.invulnerability = 0.0
	avatar.global_position = Vector2(1800, 1080)
	await physics_frame
	await physics_frame
	if avatar.dead_timer <= 0.0:
		_fail("Water hazard did not kill a falling player")
		return
	print("SMOKE PASS: authored routes, platform access, F3 debug, terrain damage, bots, drones, weapons, HUD, blasts, pickups, flight, respawn")
	quit(0)

func _terrain_at(arena: Node2D, point: Vector2):
	for child in _all_nodes(arena):
		if child.has_method("has_solid_at") and child.has_solid_at(child.to_local(point)):
			return child
	return null

func _projectile_count(arena: Node2D) -> int:
	var count := 0
	for child in _all_nodes(arena):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/projectile.gd":
			count += 1
	return count

func _newest_projectile(arena: Node2D):
	var newest = null
	for child in _all_nodes(arena):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/projectile.gd":
			newest = child
	return newest

func _all_nodes(parent: Node) -> Array[Node]:
	var result: Array[Node] = [parent]
	for child in parent.get_children():
		result.append_array(_all_nodes(child))
	return result

func _child_names(parent: Node) -> Array[String]:
	var names: Array[String] = []
	for child in parent.get_children():
		names.append(child.name)
	return names

func _f3_event() -> InputEventKey:
	root.get_node("InputManager").pulse_action("debug_level", "test:f3")
	var event := InputEventKey.new()
	event.keycode = KEY_F3
	event.pressed = true
	return event

func _falling_pickup(arena: Node2D, kind: String):
	for item in arena.pickups:
		if is_instance_valid(item) and item.kind == kind and item.falling:
			return item
	return null

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: " + message)
	quit(1)
