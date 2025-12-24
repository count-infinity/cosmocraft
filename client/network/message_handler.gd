class_name ClientMessageHandler
extends RefCounted

signal connect_response_received(success: bool, player_id: String, server_tick: int, error: String)
signal game_state_received(tick: int, players: Dictionary)
signal state_delta_received(tick: int, last_processed_input: int, players: Dictionary)
signal player_joined_received(player_data: Dictionary)
signal player_left_received(player_id: String)
signal pong_received(client_time: int, server_time: int)
signal error_received(message: String)

func handle_message(json_string: String) -> void:
	var message: Variant = Serialization.decode_message(json_string)
	if message == null:
		printerr("ClientMessageHandler: Failed to decode message")
		return

	var msg_type: String = message["type"]
	var data: Dictionary = message["data"]

	match msg_type:
		MessageTypes.CONNECT_RESPONSE:
			_handle_connect_response(data)
		MessageTypes.GAME_STATE:
			_handle_game_state(data)
		MessageTypes.STATE_DELTA:
			_handle_state_delta(data)
		MessageTypes.PLAYER_JOINED:
			_handle_player_joined(data)
		MessageTypes.PLAYER_LEFT:
			_handle_player_left(data)
		MessageTypes.PONG:
			_handle_pong(data)
		MessageTypes.ERROR:
			_handle_error(data)
		_:
			printerr("ClientMessageHandler: Unknown message type '%s'" % msg_type)

func _handle_connect_response(data: Dictionary) -> void:
	var success: bool = data.get("success", false)
	var player_id: String = data.get("player_id", "")
	var server_tick: int = int(data.get("server_tick", 0))
	var error: String = data.get("error", "")
	connect_response_received.emit(success, player_id, server_tick, error)

func _handle_game_state(data: Dictionary) -> void:
	var tick: int = int(data.get("tick", 0))
	var players: Dictionary = data.get("players", {})
	game_state_received.emit(tick, players)

func _handle_state_delta(data: Dictionary) -> void:
	var tick: int = int(data.get("tick", 0))
	var last_processed_input: int = int(data.get("last_processed_input", 0))
	var players: Dictionary = data.get("players", {})
	state_delta_received.emit(tick, last_processed_input, players)

func _handle_player_joined(data: Dictionary) -> void:
	player_joined_received.emit(data)

func _handle_player_left(data: Dictionary) -> void:
	var player_id: String = data.get("player_id", "")
	player_left_received.emit(player_id)

func _handle_pong(data: Dictionary) -> void:
	var client_time: int = int(data.get("client_time", 0))
	var server_time: int = int(data.get("server_time", 0))
	pong_received.emit(client_time, server_time)

func _handle_error(data: Dictionary) -> void:
	var message: String = data.get("message", "Unknown error")
	error_received.emit(message)
