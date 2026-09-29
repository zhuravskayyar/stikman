extends Node2D

const LevelDesign = preload("res://scripts/level_design.gd")
const PLAYER = preload("res://scripts/player.gd")

const GREEN := Color("56b879")
const RED := Color("e05252")
const BLUE := Color("56a7dc")
const YELLOW := Color("e2ba4a")
const PURPLE := Color("ac7dde")
const ORANGE := Color("e98a42")
const WHITE := Color("f2f3ee")

var enabled := false
var player: CharacterBody2D
var ground_outline := PackedVector2Array()
var platforms: Array[Dictionary] = []
var spawns: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var high_positions: Array[Dictionary] = []
var validation_issues: Array[String] = []

func configure(player_node: CharacterBody2D, outline: PackedVector2Array) -> void:
	player = player_node
	ground_outline = outline
	platforms = LevelDesign.platforms()
	spawns = [{"name": "Player", "position": LevelDesign.player_spawn()}]
	for index in range(LevelDesign.bot_spawns().size()):
		var bot_spawn: Dictionary = LevelDesign.bot_spawns()[index]
		spawns.append({"name": "Robot %d" % (index + 1), "position": bot_spawn["position"]})
	spawns.append({"name": "Drone", "position": LevelDesign.drone_spawn()})
	pickups = LevelDesign.pickup_spawns()
	high_positions = LevelDesign.high_positions()
	validation_issues = LevelDesign.route_is_clearable()

func _unhandled_input(event: InputEvent) -> void:
	if InputManager.is_action_just_pressed("debug_level"):
		enabled = not enabled
		queue_redraw()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var outline := ground_outline.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
		draw_polyline(outline, Color(WHITE, 0.8), 1.5, true)
	_draw_vertical_zones()
	_draw_platforms()
	_draw_thin_zones()
	_draw_spawns()
	_draw_pickups()
	_draw_high_positions()
	_draw_line_of_sight()
	_draw_jump_arcs()
	_draw_weapon_range()
	_draw_status()

func _draw_platforms() -> void:
	for platform in platforms:
		var at: Vector2 = platform["position"]
		var width: float = platform["width"]
		var left := at.x - width * 0.5
		var accessible := true
		for side in [-1.0, 1.0]:
			if not LevelDesign.platform_side_reachable(platform, side):
				accessible = false
		var color := GREEN if accessible else RED
		draw_rect(Rect2(Vector2(left, at.y - 14), Vector2(width, 38)), Color(color, 0.15), true)
		draw_rect(Rect2(Vector2(left, at.y - 14), Vector2(width, 38)), color, false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(left, at.y - 20), String(platform["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, color)

func _draw_vertical_zones() -> void:
	draw_line(Vector2(0, LevelDesign.HIGH_ZONE_BOTTOM), Vector2(LevelDesign.WORLD_SIZE.x, LevelDesign.HIGH_ZONE_BOTTOM), Color(PURPLE, 0.35), 1.5, true)
	draw_line(Vector2(0, LevelDesign.MID_ZONE_BOTTOM), Vector2(LevelDesign.WORLD_SIZE.x, LevelDesign.MID_ZONE_BOTTOM), Color(BLUE, 0.35), 1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(28, LevelDesign.HIGH_ZONE_BOTTOM - 10), "HIGH ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, PURPLE)
	draw_string(ThemeDB.fallback_font, Vector2(28, LevelDesign.MID_ZONE_BOTTOM - 10), "MID ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, BLUE)
	draw_string(ThemeDB.fallback_font, Vector2(28, LevelDesign.WATER_TOP - 12), "LOW / WATER RISK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, ORANGE)

func _draw_thin_zones() -> void:
	for area in LevelDesign.thin_zones():
		draw_rect(area, Color(ORANGE, 0.16), true)
		draw_rect(area, ORANGE, false, 2.0)

func _draw_spawns() -> void:
	for spawn in spawns:
		var at: Vector2 = spawn["position"]
		draw_circle(at, 11.0, Color(BLUE, 0.2))
		draw_arc(at, 13.0, 0.0, TAU, 16, BLUE, 2.0, true)
		draw_line(at + Vector2(-18, 0), at + Vector2(18, 0), BLUE, 1.5, true)
		draw_line(at + Vector2(0, -18), at + Vector2(0, 18), BLUE, 1.5, true)
		draw_string(ThemeDB.fallback_font, at + Vector2(15, -12), String(spawn["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, BLUE)

func _draw_pickups() -> void:
	for pickup in pickups:
		var at: Vector2 = pickup["position"]
		draw_circle(at, 9.0, Color(YELLOW, 0.22))
		draw_arc(at, 11.0, 0.0, TAU, 14, YELLOW, 2.0, true)
		draw_string(ThemeDB.fallback_font, at + Vector2(13, -6), String(pickup["kind"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, YELLOW)

func _draw_high_positions() -> void:
	for point in high_positions:
		var at: Vector2 = point["position"]
		var marker := PackedVector2Array([at + Vector2(0, -12), at + Vector2(12, 10), at + Vector2(-12, 10)])
		draw_colored_polygon(marker, Color(PURPLE, 0.25))
		marker.append(marker[0])
		draw_polyline(marker, PURPLE, 2.0, true)
		draw_string(ThemeDB.fallback_font, at + Vector2(15, 17), String(point["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PURPLE)

func _draw_line_of_sight() -> void:
	if spawns.size() < 2:
		return
	var player_spawn: Vector2 = spawns[0]["position"]
	for index in range(1, spawns.size()):
		var enemy_spawn: Vector2 = spawns[index]["position"]
		var clear := LevelDesign.has_clear_ground_los(player_spawn, enemy_spawn)
		draw_line(player_spawn, enemy_spawn, Color(RED if clear else GREEN, 0.55), 1.0, true)

func _draw_jump_arcs() -> void:
	var starts: Array[Vector2] = []
	for platform in platforms:
		starts.append(platform["position"])
	for start in starts:
		for direction in [-1.0, 1.0]:
			var arc := PackedVector2Array()
			for index in range(20):
				var time := LevelDesign.NORMAL_JUMP_DURATION * float(index) / 19.0
				var x: float = start.x + direction * LevelDesign.PLAYER_SPEED * time
				var y: float = start.y - LevelDesign.JUMP_SPEED * time + 0.5 * LevelDesign.GRAVITY * time * time
				arc.append(Vector2(x, y))
			draw_polyline(arc, Color(GREEN, 0.38), 1.2, true)
	var start: Vector2 = starts[0]
	var origin: Vector2 = start + Vector2(0, -LevelDesign.PLAYER_HEIGHT * 0.5)
	draw_line(origin, origin + Vector2(LevelDesign.NORMAL_JUMP_DISTANCE, 0), WHITE, 1.5, true)
	draw_line(origin, origin - Vector2(LevelDesign.NORMAL_JUMP_DISTANCE, 0), WHITE, 1.5, true)

func _draw_weapon_range() -> void:
	if not is_instance_valid(player):
		return
	var range_value: float = PLAYER.WEAPONS[player.weapon_index]["range"]
	draw_arc(player.global_position + Vector2(0, -11), range_value, 0.0, TAU, 80, Color(WHITE, 0.24), 1.2, true)
	if player.trajectory_points.size() > 1:
		var trajectory := PackedVector2Array()
		for point in player.trajectory_points:
			trajectory.append(player.to_global(point))
		draw_polyline(trajectory, Color(WHITE, 0.9), 2.0, true)

func _draw_status() -> void:
	var issues_text := "Level checks: PASS" if validation_issues.is_empty() else "Level checks: %d warnings" % validation_issues.size()
	var zoom: float = player.camera.zoom.x if is_instance_valid(player) and player.camera != null else 1.0
	var font_size := maxi(11, roundi(15.0 / zoom))
	var anchor := player.global_position + Vector2(-500.0 / zoom, -260.0 / zoom) if is_instance_valid(player) else Vector2(30, 30)
	draw_string(ThemeDB.fallback_font, anchor, "F3 DEBUG  |  %s  |  Jump %.0f px / %.0f px" % [issues_text, LevelDesign.NORMAL_JUMP_HEIGHT, LevelDesign.NORMAL_JUMP_DISTANCE], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, WHITE)
	for index in range(mini(validation_issues.size(), 5)):
		draw_string(ThemeDB.fallback_font, anchor + Vector2(0, float(index + 1) * font_size * 1.2), validation_issues[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, RED)
