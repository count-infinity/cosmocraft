class_name GameServer
extends Node

signal server_started(port: int)
signal server_stopped()
signal player_connected(player_id: String, player_name: String)
signal player_disconnected(player_id: String)

var config: ServerConfig
var game_state: GameState
var game_loop: GameLoop
var message_handler: ServerMessageHandler

var _tcp_server: TCPServer
var _peers: Dictionary = {}  # peer_id -> WebSocketPeer
var _peer_to_player: Dictionary = {}  # peer_id -> player_id
var _player_to_peer: Dictionary = {}  # player_id -> peer_id

var _running: bool = false

func _init() -> void:
	config = ServerConfig.from_args()
	game_state = GameState.new()
	game_loop = GameLoop.new(game_state)
	message_handler = ServerMessageHandler.new()

	# Connect message handler signals
	message_handler.player_connect_requested.connect(_on_player_connect_requested)
	message_handler.player_input_received.connect(_on_player_input_received)
	message_handler.player_ping_received.connect(_on_player_ping_received)
	message_handler.player_disconnect_requested.connect(_on_player_disconnect_requested)

	# Connect game loop signals
	game_loop.tick_completed.connect(_on_tick_completed)

func _ready() -> void:
	start_server()

func start_server() -> bool:
	_tcp_server = TCPServer.new()
	var error := _tcp_server.listen(config.port)
	if error != OK:
		printerr("GameServer: Failed to start server on port %d: %s" % [config.port, error_string(error)])
		return false

	_running = true
	print("GameServer: Server started on port %d" % config.port)
	server_started.emit(config.port)
	return true

func stop_server() -> void:
	_running = false

	# Disconnect all peers
	for peer_id in _peers.keys():
		_disconnect_peer(peer_id)

	_peers.clear()
	_peer_to_player.clear()
	_player_to_peer.clear()

	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null

	print("GameServer: Server stopped")
	server_stopped.emit()

func _process(delta: float) -> void:
	if not _running:
		return

	# Accept new connections
	_accept_new_connections()

	# Poll all WebSocket peers
	_poll_peers()

	# Update game loop
	game_loop.update(delta)

func _accept_new_connections() -> void:
	while _tcp_server.is_connection_available():
		var tcp_peer := _tcp_server.take_connection()
		if tcp_peer:
			var ws_peer := WebSocketPeer.new()
			var error := ws_peer.accept_stream(tcp_peer)
			if error == OK:
				var peer_id := tcp_peer.get_instance_id()
				_peers[peer_id] = ws_peer
				print("GameServer: New connection from peer %d" % peer_id)
			else:
				printerr("GameServer: Failed to accept WebSocket connection: %s" % error_string(error))

func _poll_peers() -> void:
	var peers_to_remove: Array = []

	for peer_id in _peers:
		var ws_peer: WebSocketPeer = _peers[peer_id]
		ws_peer.poll()

		var state := ws_peer.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				# Receive messages
				while ws_peer.get_available_packet_count() > 0:
					var packet := ws_peer.get_packet()
					var message := packet.get_string_from_utf8()
					message_handler.handle_message(peer_id, message)

			WebSocketPeer.STATE_CLOSING:
				# Still closing, wait
				pass

			WebSocketPeer.STATE_CLOSED:
				peers_to_remove.append(peer_id)

	# Remove disconnected peers
	for peer_id in peers_to_remove:
		_handle_peer_disconnected(peer_id)

func _handle_peer_disconnected(peer_id: int) -> void:
	if _peer_to_player.has(peer_id):
		var player_id: String = _peer_to_player[peer_id]
		_remove_player(player_id)

	_peers.erase(peer_id)
	print("GameServer: Peer %d disconnected" % peer_id)

func _disconnect_peer(peer_id: int) -> void:
	if _peers.has(peer_id):
		var ws_peer: WebSocketPeer = _peers[peer_id]
		ws_peer.close()

func _on_player_connect_requested(peer_id: int, player_name: String) -> void:
	if _peer_to_player.has(peer_id):
		# Already connected
		_send_to_peer(peer_id, Serialization.encode_connect_response(false, "", 0, "Already connected"))
		return

	if game_state.get_player_count() >= config.max_players:
		_send_to_peer(peer_id, Serialization.encode_connect_response(false, "", 0, "Server full"))
		return

	# Generate unique player ID
	var player_id := _generate_player_id()

	# Add player to game state
	var player := game_state.add_player(player_id, player_name)

	# Map peer to player
	_peer_to_player[peer_id] = player_id
	_player_to_peer[player_id] = peer_id

	# Send success response with current game state
	_send_to_peer(peer_id, Serialization.encode_connect_response(true, player_id, game_state.current_tick))
	_send_to_peer(peer_id, Serialization.encode_game_state(game_state.current_tick, game_state.players))

	# Notify other players
	_broadcast_except(peer_id, Serialization.encode_player_joined(player))

	print("GameServer: Player '%s' (ID: %s) connected from peer %d" % [player_name, player_id, peer_id])
	player_connected.emit(player_id, player_name)

func _on_player_input_received(peer_id: int, input_data: Dictionary) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	# Update last processed input sequence
	var sequence: int = input_data.get("sequence", 0)
	game_state.set_last_processed_input(player_id, sequence)

	# Queue input for next tick
	game_loop.queue_input(player_id, input_data)

func _on_player_ping_received(peer_id: int, client_time: int) -> void:
	_send_to_peer(peer_id, Serialization.encode_pong(client_time))

func _on_player_disconnect_requested(peer_id: int) -> void:
	_disconnect_peer(peer_id)

func _on_tick_completed(_tick: int) -> void:
	# Broadcast state delta to all connected players
	_broadcast_state_delta()

func _broadcast_state_delta() -> void:
	for player_id in _player_to_peer:
		var peer_id: int = _player_to_peer[player_id]
		var last_input: int = game_state.get_last_processed_input(player_id)
		var message := Serialization.encode_state_delta(game_state.current_tick, last_input, game_state.players)
		_send_to_peer(peer_id, message)

func _remove_player(player_id: String) -> void:
	if not game_state.has_player(player_id):
		return

	game_state.remove_player(player_id)

	var peer_id: int = _player_to_peer.get(player_id, -1)
	if peer_id >= 0:
		_peer_to_player.erase(peer_id)
	_player_to_peer.erase(player_id)

	# Notify other players
	_broadcast(Serialization.encode_player_left(player_id))

	player_disconnected.emit(player_id)

func _send_to_peer(peer_id: int, message: String) -> void:
	if _peers.has(peer_id):
		var ws_peer: WebSocketPeer = _peers[peer_id]
		if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws_peer.send_text(message)

func _broadcast(message: String) -> void:
	for peer_id in _peers:
		_send_to_peer(peer_id, message)

func _broadcast_except(except_peer_id: int, message: String) -> void:
	for peer_id in _peers:
		if peer_id != except_peer_id:
			_send_to_peer(peer_id, message)

func _generate_player_id() -> String:
	# Simple unique ID using timestamp and random
	var timestamp := Time.get_unix_time_from_system()
	var random := randi()
	return "%d_%d" % [int(timestamp * 1000) % 1000000, random % 10000]
