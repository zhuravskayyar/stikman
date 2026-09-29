extends Node

const SAVE_PATH := "user://profile.cfg"

var player_name := "ГРАВЕЦЬ"
var master_volume := 0.78
var fullscreen := true

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	player_name = str(config.get_value("profile", "player_name", player_name)).strip_edges()
	if player_name.is_empty():
		player_name = "ГРАВЕЦЬ"
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "player_name", player_name)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SAVE_PATH)
	apply_settings()

func apply_settings() -> void:
	AudioServer.set_bus_volume_linear(0, master_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
