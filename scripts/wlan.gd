extends Node

signal connection_established
signal connection_failed(reason: String)
signal peer_joined(peer_id: int, player_name: String)
signal peer_left(peer_id: int)
signal state_received(peer_id: int, state: Dictionary)
signal states_received(states: Array)
signal action_received(peer_id: int, action: String, payload: Dictionary)
signal status_changed
signal rooms_changed(rooms: Array, scan_finished: bool)

const GAME_PORT := 8910
const WEB_PORT := 8088
const DISCOVERY_PORT := 8911
const MAX_PLAYERS := 4
const MAX_HTTP_CHUNK := 32768
const DISCOVERY_MAGIC := "notebook-arena-room-v1"
const DISCOVERY_DURATION := 2.6

var is_host := false
var is_connected := false
var local_player_name := "PLAYER"
var peer_names: Dictionary = {}
var status_message := ""
var _server := TCPServer.new()
var _http_clients: Array[Dictionary] = []
var _discovery_server := PacketPeerUDP.new()
var _discovery_client: PacketPeerUDP
var _discovery_remaining := 0.0
var _discovered_rooms: Array[Dictionary] = []

func _process(delta: float) -> void:
	while _server.is_connection_available():
		var client := _server.take_connection()
		if client != null:
			_http_clients.append({"socket": client, "request": "", "body": PackedByteArray(), "header": PackedByteArray(), "offset": 0, "ready": false})
	for index in range(_http_clients.size() - 1, -1, -1):
		_process_http_client(index)
	_poll_host_discovery()
	_poll_room_search(delta)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_host() -> Error:
	if OS.has_feature("web"):
		return ERR_UNAVAILABLE
	stop_session()
	var socket_peer := WebSocketMultiplayerPeer.new()
	var error := socket_peer.create_server(GAME_PORT, "*")
	if error != OK:
		status_message = "Не вдалося відкрити порт %d (%d)" % [GAME_PORT, error]
		status_changed.emit()
		return error
	multiplayer.multiplayer_peer = socket_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	is_host = true
	is_connected = true
	peer_names = {1: local_player_name}
	var web_error := _server.listen(WEB_PORT, "*")
	var discovery_error := _discovery_server.bind(DISCOVERY_PORT, "0.0.0.0")
	if web_error != OK:
		status_message = "Гра працює, але Web-порт %d зайнятий" % WEB_PORT
	elif discovery_error != OK:
		status_message = "Хост працює; автопошук кімнат недоступний"
	else:
		status_message = "Хост працює та видимий у локальній мережі"
	status_changed.emit()
	return OK

func connect_to(address: String) -> Error:
	stop_session()
	var endpoint := address.strip_edges()
	if not endpoint.begins_with("ws://") and not endpoint.begins_with("wss://"):
		endpoint = "ws://" + endpoint
	var scheme_size := 6 if endpoint.begins_with("wss://") else 5
	var authority_end := endpoint.find("/", scheme_size)
	if authority_end < 0:
		authority_end = endpoint.length()
	var authority := endpoint.substr(scheme_size, authority_end - scheme_size)
	if not authority.contains(":"):
		endpoint = endpoint.insert(authority_end, ":%d" % GAME_PORT)
	var socket_peer := WebSocketMultiplayerPeer.new()
	var error := socket_peer.create_client(endpoint)
	if error != OK:
		status_message = "Не вдалося підключитися до %s (%d)" % [endpoint, error]
		status_changed.emit()
		return error
	multiplayer.multiplayer_peer = socket_peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	is_host = false
	is_connected = false
	status_message = "Підключення до хоста…"
	status_changed.emit()
	return OK

func stop_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if _server.is_listening():
		_server.stop()
	if _discovery_server.is_bound():
		_discovery_server.close()
	cancel_room_search()
	for entry in _http_clients:
		var socket: StreamPeerTCP = entry["socket"]
		socket.disconnect_from_host()
	_http_clients.clear()
	peer_names.clear()
	is_host = false
	is_connected = false
	status_message = ""
	status_changed.emit()

func is_active() -> bool:
	return is_host or is_connected

func search_rooms() -> Error:
	if OS.has_feature("web"):
		rooms_changed.emit([], true)
		return ERR_UNAVAILABLE
	cancel_room_search()
	_discovered_rooms.clear()
	var socket := PacketPeerUDP.new()
	var error := socket.bind(0, "0.0.0.0")
	if error != OK:
		status_message = "Не вдалося запустити пошук кімнат (%d)" % error
		status_changed.emit()
		rooms_changed.emit([], true)
		return error
	socket.set_broadcast_enabled(true)
	error = socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	if error == OK:
		error = socket.put_packet(JSON.stringify({"magic": DISCOVERY_MAGIC, "request": true}).to_utf8_buffer())
	if error != OK:
		socket.close()
		status_message = "Не вдалося надіслати пошук кімнат (%d)" % error
		status_changed.emit()
		rooms_changed.emit([], true)
		return error
	_discovery_client = socket
	_discovery_remaining = DISCOVERY_DURATION
	status_message = "Шукаю ігри в цій Wi‑Fi мережі…"
	status_changed.emit()
	rooms_changed.emit([], false)
	return OK

func cancel_room_search() -> void:
	if _discovery_client != null:
		_discovery_client.close()
		_discovery_client = null
	_discovery_remaining = 0.0

func local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_active() else 1

func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if not result.has(address):
			result.append(address)
	return result

func browser_url() -> String:
	var addresses := local_addresses()
	return "http://%s:%d" % [addresses[0] if not addresses.is_empty() else "IP-ПРИСТРОЮ", WEB_PORT]

func publish_local_state(state: Dictionary) -> void:
	if not is_active():
		return
	if is_host:
		state_received.emit(1, state)
	else:
		_rpc_submit_state.rpc_id(1, state)

func publish_states(states: Array) -> void:
	if is_host and multiplayer.multiplayer_peer != null:
		_rpc_receive_states.rpc(states)

func send_action(action: String, payload: Dictionary) -> void:
	if not is_active():
		return
	if is_host:
		action_received.emit(1, action, payload)
	else:
		_rpc_request_action.rpc_id(1, action, payload)

func relay_action(peer_id: int, action: String, payload: Dictionary) -> void:
	if is_host and multiplayer.multiplayer_peer != null:
		_rpc_relay_action.rpc(peer_id, action, payload)

func _on_peer_connected(_peer_id: int) -> void:
	status_message = "Гравець підключається…"
	status_changed.emit()

func _on_peer_disconnected(peer_id: int) -> void:
	peer_names.erase(peer_id)
	peer_left.emit(peer_id)
	if is_host:
		_rpc_update_roster.rpc(_make_roster())
	status_message = "Гравець від'єднався"
	status_changed.emit()

func _on_connected_to_server() -> void:
	is_connected = true
	status_message = "Надсилаю ім'я гравця…"
	_request_join.rpc_id(1, local_player_name)
	status_changed.emit()

func _on_connection_failed() -> void:
	is_connected = false
	status_message = "Не вдалося підключитися. Перевірте IP і Wi‑Fi."
	status_changed.emit()
	connection_failed.emit(status_message)

func _on_server_disconnected() -> void:
	is_connected = false
	status_message = "Зв'язок із хостом втрачено"
	status_changed.emit()
	connection_failed.emit(status_message)

@rpc("any_peer", "call_remote", "reliable")
func _request_join(player_name: String) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	if peer_names.size() >= MAX_PLAYERS:
		_rpc_join_rejected.rpc_id(sender, "У кімнаті вже максимальна кількість гравців.")
		return
	var clean_name := player_name.strip_edges().substr(0, 18)
	peer_names[sender] = clean_name if not clean_name.is_empty() else "PLAYER"
	_rpc_join_accepted.rpc_id(sender, _make_roster())
	peer_joined.emit(sender, str(peer_names[sender]))
	_rpc_update_roster.rpc(_make_roster())
	status_message = "Гравців: %d/%d" % [peer_names.size(), MAX_PLAYERS]
	status_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_join_accepted(roster: Dictionary) -> void:
	if is_host:
		return
	is_connected = true
	peer_names = roster
	status_message = "Підключено до локальної гри"
	status_changed.emit()
	for key in roster:
		if int(key) != local_peer_id():
			peer_joined.emit(int(key), str(roster[key]))
	connection_established.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_join_rejected(reason: String) -> void:
	is_connected = false
	status_message = reason
	status_changed.emit()
	connection_failed.emit(status_message)

@rpc("authority", "call_remote", "reliable")
func _rpc_update_roster(roster: Dictionary) -> void:
	if is_host:
		return
	for key in roster:
		var peer_id := int(key)
		if peer_id != local_peer_id() and not peer_names.has(peer_id):
			peer_joined.emit(peer_id, str(roster[key]))
	for existing_peer in peer_names:
		if not roster.has(existing_peer) and int(existing_peer) != local_peer_id():
			peer_left.emit(int(existing_peer))
	peer_names = roster

@rpc("any_peer", "call_remote", "unreliable", 1)
func _rpc_submit_state(state: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if peer_names.has(sender):
		state_received.emit(sender, state)

@rpc("authority", "call_remote", "unreliable", 1)
func _rpc_receive_states(states: Array) -> void:
	if not is_host:
		states_received.emit(states)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_action(action: String, payload: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if peer_names.has(sender):
		action_received.emit(sender, action, payload)

@rpc("authority", "call_remote", "reliable")
func _rpc_relay_action(peer_id: int, action: String, payload: Dictionary) -> void:
	if not is_host:
		action_received.emit(peer_id, action, payload)

func _make_roster() -> Dictionary:
	var roster := peer_names.duplicate()
	roster[1] = local_player_name
	return roster

func _process_http_client(index: int) -> void:
	var entry := _http_clients[index]
	var socket: StreamPeerTCP = entry["socket"]
	socket.poll()
	if socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_http_clients.remove_at(index)
		return
	if not entry["ready"]:
		var available := socket.get_available_bytes()
		if available > 0:
			var received := socket.get_data(available)
			if received[0] == OK:
				entry["request"] = str(entry["request"]) + received[1].get_string_from_utf8()
		if str(entry["request"]).length() > 8192:
			_http_clients.remove_at(index)
			return
		if not str(entry["request"]).contains("\r\n\r\n"):
			_http_clients[index] = entry
			return
		var request_line := str(entry["request"]).split("\r\n", false)[0].split(" ", false)
		var requested_path := "/" if request_line.size() < 2 else str(request_line[1]).split("?", false)[0]
		if requested_path == "/":
			requested_path = "/index.html"
		var filename := requested_path.trim_prefix("/")
		var valid_name := filename.is_valid_filename() and not filename.contains("..")
		var file_path := "res://build/web/" + filename
		var body := FileAccess.get_file_as_bytes(file_path) if valid_name and FileAccess.file_exists(file_path) else PackedByteArray()
		var status := "200 OK" if not body.is_empty() else "404 Not Found"
		var mime := _mime_type(filename)
		entry["body"] = body
		entry["header"] = ("HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n" % [status, mime, body.size()]).to_utf8_buffer()
		entry["ready"] = true
		_http_clients[index] = entry
	var header: PackedByteArray = entry["header"]
	var header_offset: int = entry["offset"]
	if header_offset < header.size():
		var header_result := socket.put_partial_data(header.slice(header_offset, mini(header.size(), header_offset + MAX_HTTP_CHUNK)))
		if header_result[0] != OK:
			_http_clients.remove_at(index)
			return
		entry["offset"] = header_offset + int(header_result[1])
		header_offset = int(entry["offset"])
	if header_offset < header.size():
		_http_clients[index] = entry
		return
	var body: PackedByteArray = entry["body"]
	var body_offset: int = int(entry.get("body_offset", 0))
	if body_offset < body.size():
		var body_result := socket.put_partial_data(body.slice(body_offset, mini(body.size(), body_offset + MAX_HTTP_CHUNK)))
		if body_result[0] != OK:
			_http_clients.remove_at(index)
			return
		body_offset += int(body_result[1])
		entry["body_offset"] = body_offset
		if body_offset < body.size():
			_http_clients[index] = entry
			return
	_http_clients.remove_at(index)
	socket.disconnect_from_host()

func _mime_type(filename: String) -> String:
	match filename.get_extension().to_lower():
		"html": return "text/html; charset=utf-8"
		"js": return "application/javascript"
		"wasm": return "application/wasm"
		"png": return "image/png"
		"svg": return "image/svg+xml"
		"json": return "application/json"
		"css": return "text/css"
		"pck": return "application/octet-stream"
		_: return "application/octet-stream"

func _poll_host_discovery() -> void:
	if not _discovery_server.is_bound():
		return
	while _discovery_server.get_available_packet_count() > 0:
		var request_text := _discovery_server.get_packet().get_string_from_utf8()
		var sender_ip := _discovery_server.get_packet_ip()
		var sender_port := _discovery_server.get_packet_port()
		var request: Variant = JSON.parse_string(request_text)
		if not request is Dictionary or request.get("magic", "") != DISCOVERY_MAGIC or not bool(request.get("request", false)):
			continue
		var response := {
			"magic": DISCOVERY_MAGIC,
			"game_port": GAME_PORT,
			"host_name": local_player_name,
			"players": peer_names.size(),
			"player_limit": MAX_PLAYERS
		}
		if _discovery_server.set_dest_address(sender_ip, sender_port) == OK:
			_discovery_server.put_packet(JSON.stringify(response).to_utf8_buffer())

func _poll_room_search(delta: float) -> void:
	if _discovery_client == null:
		return
	while _discovery_client.get_available_packet_count() > 0:
		var packet_text := _discovery_client.get_packet().get_string_from_utf8()
		var host_ip := _discovery_client.get_packet_ip()
		var response: Variant = JSON.parse_string(packet_text)
		if not response is Dictionary or response.get("magic", "") != DISCOVERY_MAGIC:
			continue
		if host_ip.is_empty() or host_ip.contains(":") or host_ip.begins_with("127.") or host_ip.begins_with("169.254."):
			continue
		var game_port := int(response.get("game_port", GAME_PORT))
		if game_port <= 0 or game_port > 65535:
			continue
		var room_address := "%s:%d" % [host_ip, game_port]
		var room := {
			"address": room_address,
			"host_name": str(response.get("host_name", "HOST")).strip_edges().substr(0, 18),
			"players": clampi(int(response.get("players", 1)), 1, MAX_PLAYERS),
			"player_limit": clampi(int(response.get("player_limit", MAX_PLAYERS)), 1, MAX_PLAYERS)
		}
		var existing_index := -1
		for index in range(_discovered_rooms.size()):
			if str(_discovered_rooms[index].get("address", "")) == room_address:
				existing_index = index
				break
		if existing_index >= 0:
			_discovered_rooms[existing_index] = room
		else:
			_discovered_rooms.append(room)
		rooms_changed.emit(_discovered_rooms.duplicate(true), false)
	_discovery_remaining -= delta
	if _discovery_remaining <= 0.0:
		cancel_room_search()
		status_message = "Знайдено кімнат: %d" % _discovered_rooms.size() if not _discovered_rooms.is_empty() else "Кімнат не знайдено — перевірте Wi‑Fi або введіть адресу вручну"
		status_changed.emit()
		rooms_changed.emit(_discovered_rooms.duplicate(true), true)
