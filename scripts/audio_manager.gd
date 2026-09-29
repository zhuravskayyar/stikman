extends Node

const LASER_SHOTS := [
	preload("res://assets/audio/weapons/laser_shot/laser_shot_01.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_02.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_03.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_04.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_05.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_06.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_07.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_08.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_09.ogg"),
	preload("res://assets/audio/weapons/laser_shot/laser_shot_10.ogg"),
]
const EXPLOSIONS := [
	preload("res://assets/audio/weapons/explosion/explosion_01.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_02.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_03.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_04.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_05.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_06.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_07.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_08.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_09.ogg"),
	preload("res://assets/audio/weapons/explosion/explosion_10.ogg"),
]
const IMPACTS := [
	preload("res://assets/audio/character/hit/hit_01.ogg"),
	preload("res://assets/audio/character/hit/hit_02.ogg"),
	preload("res://assets/audio/character/hit/hit_03.ogg"),
	preload("res://assets/audio/character/hit/hit_04.ogg"),
	preload("res://assets/audio/character/hit/hit_05.ogg"),
	preload("res://assets/audio/character/hit/hit_06.ogg"),
	preload("res://assets/audio/character/hit/hit_07.ogg"),
	preload("res://assets/audio/character/hit/hit_08.ogg"),
	preload("res://assets/audio/character/hit/hit_09.ogg"),
	preload("res://assets/audio/character/hit/hit_10.ogg"),
]
const JUMPS := [
	preload("res://assets/audio/movement/jump/jump_01.ogg"),
	preload("res://assets/audio/movement/jump/jump_02.ogg"),
	preload("res://assets/audio/movement/jump/jump_03.ogg"),
	preload("res://assets/audio/movement/jump/jump_04.ogg"),
	preload("res://assets/audio/movement/jump/jump_05.ogg"),
	preload("res://assets/audio/movement/jump/jump_06.ogg"),
	preload("res://assets/audio/movement/jump/jump_07.ogg"),
	preload("res://assets/audio/movement/jump/jump_08.ogg"),
	preload("res://assets/audio/movement/jump/jump_09.ogg"),
	preload("res://assets/audio/movement/jump/jump_10.ogg"),
]
const UI_BLIPS := [
	preload("res://assets/audio/ui/blip/blip_01.ogg"),
	preload("res://assets/audio/ui/blip/blip_02.ogg"),
	preload("res://assets/audio/ui/blip/blip_03.ogg"),
	preload("res://assets/audio/ui/blip/blip_04.ogg"),
	preload("res://assets/audio/ui/blip/blip_05.ogg"),
	preload("res://assets/audio/ui/blip/blip_06.ogg"),
	preload("res://assets/audio/ui/blip/blip_07.ogg"),
	preload("res://assets/audio/ui/blip/blip_08.ogg"),
	preload("res://assets/audio/ui/blip/blip_09.ogg"),
	preload("res://assets/audio/ui/blip/blip_10.ogg"),
]
const PICKUPS := [
	preload("res://assets/audio/ui/pickup/pickup_01.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_02.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_03.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_04.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_05.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_06.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_07.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_08.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_09.ogg"),
	preload("res://assets/audio/ui/pickup/pickup_10.ogg"),
]

const SOUND_VARIANTS := {
	&"weapon_fire": LASER_SHOTS,
	&"grenade_throw": LASER_SHOTS,
	&"impact": IMPACTS,
	&"terrain_impact": IMPACTS,
	&"debris": IMPACTS,
	&"character_hurt": IMPACTS,
	&"punch": IMPACTS,
	&"land": IMPACTS,
	&"jump": JUMPS,
	&"pickup": PICKUPS,
	&"ui_click": UI_BLIPS,
	&"weapon_select": UI_BLIPS,
	&"reload": UI_BLIPS,
	&"explosion": EXPLOSIONS,
	&"terrain_destroy": EXPLOSIONS,
	&"enemy_death": EXPLOSIONS,
	&"death": EXPLOSIONS,
}

const PLAYER_POOL_SIZE := 16
const SPATIAL_POOL_SIZE := 24
const SPATIAL_GAIN_DB := 8.0

var _random := RandomNumberGenerator.new()
var _players: Array[AudioStreamPlayer] = []
var _spatial_players: Array[AudioStreamPlayer2D] = []
var _last_variant_by_event: Dictionary = {}
var _next_player := 0
var _next_spatial_player := 0

func _ready() -> void:
	_random.randomize()
	for _ui_index in range(PLAYER_POOL_SIZE):
		var ui_player := AudioStreamPlayer.new()
		ui_player.bus = "Master"
		ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ui_player)
		_players.append(ui_player)
	for _spatial_index in range(SPATIAL_POOL_SIZE):
		var world_player := AudioStreamPlayer2D.new()
		world_player.bus = "Master"
		world_player.max_distance = 1800.0
		world_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(world_player)
		_spatial_players.append(world_player)

func set_world_root(world_root: Node2D) -> void:
	if not is_instance_valid(world_root):
		return
	for world_player in _spatial_players:
		if world_player.get_parent() != world_root:
			world_player.reparent(world_root, false)

func clear_world_root() -> void:
	for world_player in _spatial_players:
		if world_player.get_parent() != self:
			world_player.reparent(self, false)

func play_sfx(event_name: StringName, volume_db := 0.0, pitch_scale := 1.0, pitch_variation := 0.06) -> void:
	_play(event_name, false, Vector2.ZERO, volume_db, pitch_scale, pitch_variation)

func play_at(event_name: StringName, world_position: Vector2, volume_db := 0.0, pitch_scale := 1.0, pitch_variation := 0.06) -> void:
	_play(event_name, true, world_position, volume_db, pitch_scale, pitch_variation)

func _play(event_name: StringName, spatialized: bool, world_position: Vector2, volume_db: float, pitch_scale: float, pitch_variation: float) -> void:
	var variations: Array = SOUND_VARIANTS.get(event_name, [])
	if variations.is_empty():
		return
	var variant_index := _random.randi_range(0, variations.size() - 1)
	var previous_index: int = _last_variant_by_event.get(event_name, -1)
	if variations.size() > 1 and variant_index == previous_index:
		variant_index = (variant_index + _random.randi_range(1, variations.size() - 1)) % variations.size()
	_last_variant_by_event[event_name] = variant_index
	var stream := variations[variant_index] as AudioStream
	var final_pitch := pitch_scale * _random.randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	if spatialized:
		var spatial_player: AudioStreamPlayer2D = _spatial_players[_next_spatial_player]
		_next_spatial_player = (_next_spatial_player + 1) % _spatial_players.size()
		spatial_player.stop()
		spatial_player.global_position = world_position
		spatial_player.stream = stream
		spatial_player.volume_db = volume_db + SPATIAL_GAIN_DB
		spatial_player.pitch_scale = final_pitch
		spatial_player.play()
	else:
		var ui_player: AudioStreamPlayer = _players[_next_player]
		_next_player = (_next_player + 1) % _players.size()
		ui_player.stop()
		ui_player.stream = stream
		ui_player.volume_db = volume_db
		ui_player.pitch_scale = final_pitch
		ui_player.play()
