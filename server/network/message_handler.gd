class_name ServerMessageHandler
extends RefCounted

signal player_connect_requested(peer_id: int, player_name: String)
signal player_input_received(peer_id: int, input_data: Dictionary)
signal player_ping_received(peer_id: int, client_time: int)
signal player_disconnect_requested(peer_id: int)

# Process an incoming message from a client
func handle_message(peer_id: int, json_string: String) -> void:
	var message: Variant = Serialization.decode_message(json_string)
	if message == null:
		printerr("ServerMessageHandler: Failed to decode message from peer %d" % peer_id)
		return

	var msg_type: String = message["type"]
	var data: Dictionary = message["data"]

	match msg_type:
		MessageTypes.CONNECT_REQUEST:
			_handle_connect_request(peer_id, data)
		MessageTypes.PLAYER_INPUT:
			_handle_player_input(peer_id, data)
		MessageTypes.PING:
			_handle_ping(peer_id, data)
		MessageTypes.DISCONNECT:
			_handle_disconnect(peer_id)
		_:
			printerr("ServerMessageHandler: Unknown message type '%s' from peer %d" % [msg_type, peer_id])

func _handle_connect_request(peer_id: int, data: Dictionary) -> void:
	var player_name: String = data.get("player_name", "Unknown")
	player_connect_requested.emit(peer_id, player_name)

func _handle_player_input(peer_id: int, data: Dictionary) -> void:
	var input_data := Serialization.parse_player_input(data)
	player_input_received.emit(peer_id, input_data)

func _handle_ping(peer_id: int, data: Dictionary) -> void:
	var client_time: int = data.get("client_time", 0)
	player_ping_received.emit(peer_id, client_time)

func _handle_disconnect(peer_id: int) -> void:
	player_disconnect_requested.emit(peer_id)
