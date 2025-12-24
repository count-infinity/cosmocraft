class_name GameClient
extends Node

signal connected(player_id: String)
signal disconnected()
signal connection_failed(reason: String)

var config: ClientConfig
var message_handler: ClientMessageHandler

var _ws: WebSocketPeer
var _connected: bool = false
var _player_id: String = ""
var _server_tick: int = 0

# Scene references
var world: TestWorld
var local_player: LocalPlayer
var remote_players: Dictionary = {}  # player_id -> RemotePlayer

# Preloaded scenes
var LocalPlayerScene: PackedScene = preload("res://client/player/local_player.tscn")
var RemotePlayerScene: PackedScene = preload("res://client/player/remote_player.tscn")
var TestWorldScene: PackedScene = preload("res://client/world/test_world.tscn")

func _init() -> void:
	config = ClientConfig.new()
	message_handler = ClientMessageHandler.new()

	# Connect message handler signals
	message_handler.connect_response_received.connect(_on_connect_response)
	message_handler.game_state_received.connect(_on_game_state)
	message_handler.state_delta_received.connect(_on_state_delta)
	message_handler.player_joined_received.connect(_on_player_joined)
	message_handler.player_left_received.connect(_on_player_left)
	message_handler.pong_received.connect(_on_pong)
	message_handler.error_received.connect(_on_error)

func connect_to_server(address: String, port: int, player_name: String) -> void:
	config.server_address = address
	config.server_port = port
	config.player_name = player_name

	_ws = WebSocketPeer.new()
	var url := config.get_websocket_url()
	var error := _ws.connect_to_url(url)

	if error != OK:
		connection_failed.emit("Failed to initiate connection: %s" % error_string(error))
		return

	print("GameClient: Connecting to %s..." % url)

func disconnect_from_server() -> void:
	if _ws:
		_send(Serialization.encode_message(MessageTypes.DISCONNECT, {}))
		_ws.close()
	_cleanup()
	disconnected.emit()

func _process(delta: float) -> void:
	if _ws == null:
		return

	_ws.poll()

	var state := _ws.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				# Send connect request
				_send(Serialization.encode_connect_request(config.player_name))

			# Receive messages
			while _ws.get_available_packet_count() > 0:
				var packet := _ws.get_packet()
				var message := packet.get_string_from_utf8()
				message_handler.handle_message(message)

		WebSocketPeer.STATE_CLOSING:
			pass

		WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			var reason := _ws.get_close_reason()
			print("GameClient: Connection closed. Code: %d, Reason: %s" % [code, reason])
			_cleanup()
			disconnected.emit()

		WebSocketPeer.STATE_CONNECTING:
			pass

func _send(message: String) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(message)

func _cleanup() -> void:
	_connected = false
	_player_id = ""

	if local_player:
		local_player.queue_free()
		local_player = null

	for player_id in remote_players:
		remote_players[player_id].queue_free()
	remote_players.clear()

	if world:
		world.queue_free()
		world = null

	_ws = null

func _on_connect_response(success: bool, player_id: String, server_tick: int, error: String) -> void:
	if success:
		_player_id = player_id
		_server_tick = server_tick
		print("GameClient: Connected as %s (ID: %s)" % [config.player_name, player_id])
		connected.emit(player_id)
	else:
		print("GameClient: Connection rejected: %s" % error)
		connection_failed.emit(error)
		_ws.close()

func _on_game_state(tick: int, players: Dictionary) -> void:
	_server_tick = tick

	# Create world if not exists
	if world == null:
		world = TestWorldScene.instantiate()
		add_child(world)

	# Process all players
	for player_id in players:
		var player_data: Dictionary = players[player_id]
		var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])
		var aim: float = player_data.get("aim_angle", 0.0)
		var name: String = player_data.get("name", "Unknown")

		if player_id == _player_id:
			# Create local player
			if local_player == null:
				local_player = LocalPlayerScene.instantiate()
				local_player.initialize(player_id, name, pos)
				local_player.input_generated.connect(_on_local_player_input)
				add_child(local_player)
		else:
			# Create or update remote player
			if not remote_players.has(player_id):
				var remote := RemotePlayerScene.instantiate()
				remote.initialize(player_id, name, pos)
				remote_players[player_id] = remote
				add_child(remote)
			else:
				remote_players[player_id].update_state(pos, aim)

func _on_state_delta(tick: int, last_processed_input: int, players: Dictionary) -> void:
	_server_tick = tick

	for player_id in players:
		var player_data: Dictionary = players[player_id]
		var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])
		var aim: float = player_data.get("aim_angle", 0.0)

		if player_id == _player_id:
			# Reconcile local player
			if local_player:
				local_player.apply_server_state(pos, aim, last_processed_input, GameConstants.TICK_INTERVAL)
		else:
			# Update remote player
			if remote_players.has(player_id):
				remote_players[player_id].update_state(pos, aim)

func _on_player_joined(player_data: Dictionary) -> void:
	var player_id: String = player_data.get("id", "")
	var name: String = player_data.get("name", "Unknown")
	var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])

	if player_id != _player_id and not remote_players.has(player_id):
		var remote := RemotePlayerScene.instantiate()
		remote.initialize(player_id, name, pos)
		remote_players[player_id] = remote
		add_child(remote)
		print("GameClient: Player joined: %s" % name)

func _on_player_left(player_id: String) -> void:
	if remote_players.has(player_id):
		print("GameClient: Player left: %s" % player_id)
		remote_players[player_id].queue_free()
		remote_players.erase(player_id)

func _on_pong(client_time: int, _server_time: int) -> void:
	var now := Time.get_ticks_msec()
	var rtt := now - client_time
	# Could display this in HUD
	pass

func _on_error(message: String) -> void:
	print("GameClient: Server error: %s" % message)

func _on_local_player_input(input_data: Dictionary) -> void:
	# Send input to server
	var message := Serialization.encode_player_input(
		input_data["sequence"],
		input_data["move_direction"],
		input_data["aim_angle"],
		input_data["actions"]
	)
	_send(message)

func is_connected_to_server() -> bool:
	return _connected and _player_id != ""

func get_player_id() -> String:
	return _player_id
