extends Node

const MUSIC_TRACK: AudioStreamMP3 = preload("res://assets/audio/music/gritty_groove.mp3")
const MUSIC_VOLUME_DB := -10.0

var _player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stream := MUSIC_TRACK.duplicate() as AudioStreamMP3
	stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.bus = "Master"
	_player.volume_db = MUSIC_VOLUME_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = stream
	add_child(_player)
	_player.play()
