extends RefCounted

const WORLD_SIZE := Vector2(1672.0, 941.0)
const WATER_TOP := 918.0
const HIGH_ZONE_BOTTOM := 300.0
const MID_ZONE_BOTTOM := 620.0
const DEFAULT_ZOOM := 0.86

const PLAYER_WIDTH := 14.0
const PLAYER_HEIGHT := 40.0
const PLAYER_SPEED := 120.0
const GRAVITY := 1100.0
const JUMP_SPEED := 500.0
const NORMAL_JUMP_DURATION := 2.0 * JUMP_SPEED / GRAVITY
const NORMAL_JUMP_HEIGHT := JUMP_SPEED * JUMP_SPEED / (2.0 * GRAVITY)
const NORMAL_JUMP_DISTANCE := PLAYER_SPEED * NORMAL_JUMP_DURATION
const TERRAIN_MASK_TEXTURE: Texture2D = preload("res://assets/arena_mask.png")

static func player_spawn() -> Vector2:
	return Vector2(370.0, 105.0)

static func platforms() -> Array[Dictionary]:
	return [
		{"name": "west_overlook", "position": Vector2(360, 130), "width": 300.0, "category": "large", "purpose": "starting island", "color": Color("bdcdbd")},
		{"name": "west_lower_shelf", "position": Vector2(500, 340), "width": 300.0, "category": "large", "purpose": "lower route", "color": Color("c5d0c4")},
		{"name": "center_island", "position": Vector2(930, 220), "width": 310.0, "category": "large", "purpose": "central combat branch", "color": Color("c9d3c9")},
		{"name": "east_overlook", "position": Vector2(1430, 145), "width": 350.0, "category": "large", "purpose": "exposed high ground", "color": Color("bfd0c9")},
		{"name": "south_east_shelf", "position": Vector2(1320, 550), "width": 350.0, "category": "large", "purpose": "risky lower route", "color": Color("c5cfbd")}
	]

static func bot_spawns() -> Array[Dictionary]:
	return [
		{"position": Vector2(500, 320), "weapon": 2},
		{"position": Vector2(980, 162), "weapon": 3},
		{"position": Vector2(1360, 504), "weapon": 5}
	]

static func drone_spawn() -> Vector2:
	return Vector2(780.0, 160.0)

static func pickup_spawns() -> Array[Dictionary]:
	return [
		{"kind": "fuel", "position": Vector2(600, 310)},
		{"kind": "health", "position": Vector2(900, 194)},
		{"kind": "ammo", "position": Vector2(1060, 190)},
		{"kind": "fuel", "position": Vector2(1600, 75)},
		{"kind": "health", "position": Vector2(1200, 300)},
		{"kind": "sniper", "position": Vector2(1450, 130)},
		{"kind": "grenade", "position": Vector2(1090, 276)},
		{"kind": "saw", "position": Vector2(850, 222)},
		{"kind": "shuriken", "position": Vector2(720, 480)}
	]

static func high_positions() -> Array[Dictionary]:
	return [
		{"name": "west_peak", "position": Vector2(360, 130)},
		{"name": "center_peak", "position": Vector2(980, 180)},
		{"name": "east_peak", "position": Vector2(1430, 145)}
	]

static func thin_zones() -> Array[Rect2]:
	return []

static func route_is_clearable() -> Array[String]:
	var issues: Array[String] = []
	var mask := TERRAIN_MASK_TEXTURE.get_image()
	if mask == null:
		return ["Arena collision mask could not be loaded"]
	if mask.get_size() != Vector2i(WORLD_SIZE):
		issues.append("Arena mask dimensions do not match the world")
	var spawns := [{"name": "Player", "position": player_spawn()}]
	spawns.append_array(bot_spawns())
	for spawn in spawns:
		var position: Vector2 = spawn["position"]
		if not is_point_safe(position):
			issues.append("%s spawn is outside the playable area" % String(spawn.get("name", "Bot")))
		elif not _has_support(mask, position):
			issues.append("%s spawn has no terrain beneath it" % String(spawn.get("name", "Bot")))
	return issues

static func platform_side_reachable(_platform: Dictionary, _side: float) -> bool:
	return true

static func has_clear_ground_los(from: Vector2, to: Vector2) -> bool:
	var mask := TERRAIN_MASK_TEXTURE.get_image()
	if mask == null:
		return false
	var steps := maxi(1, ceili(from.distance_to(to) / 12.0))
	for index in range(1, steps):
		var point := from.lerp(to, float(index) / float(steps))
		if point.x >= 0.0 and point.y >= 0.0 and point.x < mask.get_width() and point.y < mask.get_height():
			if mask.get_pixel(floori(point.x), floori(point.y)).r > 0.5:
				return false
	return true

static func is_point_safe(point: Vector2) -> bool:
	return point.x >= PLAYER_WIDTH and point.x <= WORLD_SIZE.x - PLAYER_WIDTH and point.y > 0.0 and point.y < WATER_TOP - PLAYER_HEIGHT * 0.5

static func _has_support(mask: Image, position: Vector2) -> bool:
	var foot_y := roundi(position.y + PLAYER_HEIGHT * 0.5)
	for x_offset in [-12, 0, 12]:
		var x: int = roundi(position.x) + int(x_offset)
		if x < 0 or x >= mask.get_width():
			continue
		for y in range(maxi(0, foot_y - 3), mini(mask.get_height(), foot_y + 8)):
			if mask.get_pixel(x, y).r > 0.5:
				return true
	return false
