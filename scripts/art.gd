extends RefCounted

const CHARACTER = preload("res://assets/character_atlas_v2.png")
const ARMS = preload("res://assets/arms_atlas.png")
const JETPACK = preload("res://assets/jetpack_atlas.png")
const WEAPONS = preload("res://assets/weapons_atlas.png")
const DAMAGE = preload("res://assets/damage_atlas.png")
const FX = preload("res://assets/fx_atlas.png")
const BULLETS = preload("res://assets/bullet_atlas.png")
const UI = preload("res://assets/ui_atlas.png")
const CROSSHAIR = preload("res://assets/crosshair_atlas.png")
const HUD_SKETCH = preload("res://assets/hud_sketch.png")
const DRONE = preload("res://assets/drone_atlas.png")
const ROBOT = preload("res://assets/robot_atlas.png")
const GRENADES = preload("res://assets/grenade_atlas.png")
const SHURIKENS = preload("res://assets/shuriken_atlas.png")
const SAW_LAUNCHER = preload("res://assets/saw_launcher_atlas.png")
const SAW_BLADES = preload("res://assets/saw_blade_atlas.png")
const DUAL_PISTOLS = preload("res://assets/weapons_dual_pistols.png")
const DUAL_UZIS = preload("res://assets/weapons_dual_uzis.png")

static func region(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var piece := AtlasTexture.new()
	piece.atlas = texture
	piece.region = rect
	return piece

static func character_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_character_animation(frames, "fly_intro", 0, 12.0, false, 0, 4)
	_add_character_animation(frames, "fly", 0, 10.0, true, 4, 4)
	_add_character_animation(frames, "run", 1, 12.0, true)
	_add_character_animation(frames, "idle", 2, 7.0, true)
	_add_character_animation(frames, "jump", 3, 12.0, false)
	_add_character_animation(frames, "fall", 4, 10.0, true)
	_add_character_animation(frames, "land", 5, 18.0, false)
	_add_character_animation(frames, "hurt", 6, 24.0, false)
	_add_character_animation(frames, "death", 7, 8.0, false)
	return frames

static func _add_character_animation(frames: SpriteFrames, name: String, row: int, fps: float, looping: bool, first_frame := 0, frame_count := 8) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, looping)
	for frame in range(first_frame, first_frame + frame_count):
		frames.add_frame(name, region(CHARACTER, Rect2(frame * 256, row * 256, 256, 256)))

static func weapon(index: int) -> AtlasTexture:
	match index:
		0: return region(DUAL_PISTOLS, Rect2(Vector2.ZERO, DUAL_PISTOLS.get_size()))
		1: return region(DUAL_UZIS, Rect2(Vector2.ZERO, DUAL_UZIS.get_size()))
		2: return region(WEAPONS, Rect2(15, 815, 465, 195))
		3: return region(WEAPONS, Rect2(850, 545, 585, 185))
		4: return region(WEAPONS, Rect2(465, 820, 505, 180))
		5: return region(WEAPONS, Rect2(980, 835, 465, 180))
		6: return region(SAW_LAUNCHER, Rect2(0, 180, 362, 364))
		7: return shuriken_frame(0)
	return region(WEAPONS, Rect2(40, 525, 285, 230))

static func grenade_frame(index: int) -> AtlasTexture:
	var column := posmod(index, 4)
	var row := posmod(int(index / 4), 2)
	return region(GRENADES, Rect2(column * 362, row * 543, 362, 543))

static func shuriken_frame(index: int) -> AtlasTexture:
	var frame := posmod(index, 6)
	return region(SHURIKENS, Rect2(frame * 362, 181, 362, 362))

static func saw_blade_frame(index: int) -> AtlasTexture:
	var frame := posmod(index, 8)
	var column := frame % 4
	var row := int(frame / 4)
	var top := 181 if row == 0 else 724
	return region(SAW_BLADES, Rect2(column * 362, top, 362, 362))

static func jetpack(active: bool, frame: int = 0) -> AtlasTexture:
	if not active:
		return region(JETPACK, Rect2(105, 685, 305, 340))
	if frame % 2 == 0:
		return region(JETPACK, Rect2(75, 5, 355, 560))
	return region(JETPACK, Rect2(525, 0, 395, 565))

static func drone_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ["hover", "attack", "death"]:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 8.0 if animation == "hover" else 10.0)
		frames.set_animation_loop(animation, animation == "hover")
	for column in range(4):
		frames.add_frame("hover", region(DRONE, Rect2(column * 362, 60, 362, 295)))
		frames.add_frame("attack", region(DRONE, Rect2(column * 362, 400, 362, 300)))
		frames.add_frame("death", region(DRONE, Rect2(column * 362, 710, 362, 376)))
	return frames

static func robot_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ["hover", "attack", "death"]:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 7.0 if animation == "hover" else 10.0)
		frames.set_animation_loop(animation, animation == "hover")
	for column in range(4):
		frames.add_frame("hover", region(ROBOT, Rect2(column * 362, 0, 362, 362)))
		frames.add_frame("attack", region(ROBOT, Rect2(column * 362, 362, 362, 362)))
		frames.add_frame("death", region(ROBOT, Rect2(column * 362, 724, 362, 362)))
	return frames

static func hud_sketch(kind: String) -> AtlasTexture:
	match kind:
		"health_top": return region(HUD_SKETCH, Rect2(128, 138, 484, 14))
		"health_bottom": return region(HUD_SKETCH, Rect2(128, 213, 484, 13))
		"health_left": return region(HUD_SKETCH, Rect2(127, 142, 18, 75))
		"health_right": return region(HUD_SKETCH, Rect2(599, 142, 16, 75))
		"fuel_top": return region(HUD_SKETCH, Rect2(99, 267, 193, 77))
		"fuel_left": return region(HUD_SKETCH, Rect2(102, 300, 22, 175))
		"fuel_right": return region(HUD_SKETCH, Rect2(268, 300, 20, 175))
		"fuel_bottom": return region(HUD_SKETCH, Rect2(107, 467, 178, 17))
		"punch": return region(HUD_SKETCH, Rect2(995, 215, 420, 385))
		"fly": return region(HUD_SKETCH, Rect2(718, 525, 385, 445))
	return region(HUD_SKETCH, Rect2(128, 139, 484, 20))

static func pickup(kind: String) -> AtlasTexture:
	match kind:
		"health": return region(WEAPONS, Rect2(25, 185, 325, 300))
		"fuel": return region(WEAPONS, Rect2(400, 165, 260, 325))
		"ammo": return region(WEAPONS, Rect2(700, 235, 330, 260))
		"pistol": return weapon(0)
		"uzi": return weapon(1)
		"ak47": return weapon(2)
		"shotgun": return weapon(3)
		"sniper": return weapon(4)
		"rocket": return weapon(5)
		"grenade": return grenade_frame(0)
		"saw": return weapon(6)
		"shuriken": return weapon(7)
	return region(WEAPONS, Rect2(1040, 200, 395, 270))

static func damage(stage: int) -> AtlasTexture:
	match stage:
		1: return region(DAMAGE, Rect2(45, 190, 170, 205))
		2: return region(DAMAGE, Rect2(285, 135, 275, 270))
		3: return region(DAMAGE, Rect2(620, 50, 390, 390))
	return region(DAMAGE, Rect2(1070, 55, 335, 365))

static func effect(kind: String) -> AtlasTexture:
	match kind:
		"muzzle": return region(FX, Rect2(35, 20, 295, 185))
		"impact": return region(FX, Rect2(955, 500, 240, 205))
		"dust": return region(FX, Rect2(40, 515, 265, 190))
		"explosion": return region(FX, Rect2(555, 715, 340, 230))
	return region(FX, Rect2(955, 500, 240, 205))
