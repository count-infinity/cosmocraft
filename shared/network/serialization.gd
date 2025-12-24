class_name Serialization
extends RefCounted

# Encode a message to JSON string
static func encode_message(type: String, data: Dictionary) -> String:
	var message := {
		"type": type,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}
	return JSON.stringify(message)

# Decode a JSON string to message dictionary
# Returns null if invalid
static func decode_message(json_string: String) -> Variant:
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		printerr("Serialization: Failed to parse JSON: " + json.get_error_message())
		return null

	var result = json.get_data()
	if not result is Dictionary:
		printerr("Serialization: Expected Dictionary, got " + str(typeof(result)))
		return null

	if not result.has("type"):
		printerr("Serialization: Missing 'type' field")
		return null

	if not result.has("data"):
		printerr("Serialization: Missing 'data' field")
		return null

	return result

# Helper to create a connect_request message
static func encode_connect_request(player_name: String) -> String:
	return encode_message(MessageTypes.CONNECT_REQUEST, {
		"player_name": player_name
	})

# Helper to create a player_input message
static func encode_player_input(sequence: int, move_direction: Vector2, aim_angle: float, actions: Array = []) -> String:
	return encode_message(MessageTypes.PLAYER_INPUT, {
		"sequence": sequence,
		"move_direction": {"x": move_direction.x, "y": move_direction.y},
		"aim_angle": aim_angle,
		"actions": actions
	})

# Helper to create a ping message
static func encode_ping() -> String:
	return encode_message(MessageTypes.PING, {
		"client_time": Time.get_ticks_msec()
	})

# Helper to create a connect_response message
static func encode_connect_response(success: bool, player_id: String, server_tick: int, error_message: String = "") -> String:
	return encode_message(MessageTypes.CONNECT_RESPONSE, {
		"success": success,
		"player_id": player_id,
		"server_tick": server_tick,
		"tick_rate": GameConstants.TICK_RATE,
		"error": error_message
	})

# Helper to create a game_state message (full snapshot)
static func encode_game_state(tick: int, players: Dictionary) -> String:
	var players_data := {}
	for player_id in players:
		var player: PlayerState = players[player_id]
		players_data[player_id] = player.to_dict()

	return encode_message(MessageTypes.GAME_STATE, {
		"tick": tick,
		"players": players_data
	})

# Helper to create a state_delta message
static func encode_state_delta(tick: int, last_processed_input: int, players: Dictionary) -> String:
	var players_data := {}
	for player_id in players:
		var player: PlayerState = players[player_id]
		players_data[player_id] = {
			"position": {"x": player.position.x, "y": player.position.y},
			"velocity": {"x": player.velocity.x, "y": player.velocity.y},
			"aim_angle": player.aim_angle
		}

	return encode_message(MessageTypes.STATE_DELTA, {
		"tick": tick,
		"last_processed_input": last_processed_input,
		"players": players_data
	})

# Helper to create a player_joined message
static func encode_player_joined(player: PlayerState) -> String:
	return encode_message(MessageTypes.PLAYER_JOINED, player.to_dict())

# Helper to create a player_left message
static func encode_player_left(player_id: String) -> String:
	return encode_message(MessageTypes.PLAYER_LEFT, {
		"player_id": player_id
	})

# Helper to create a pong message
static func encode_pong(client_time: int) -> String:
	return encode_message(MessageTypes.PONG, {
		"client_time": client_time,
		"server_time": Time.get_ticks_msec()
	})

# Helper to create an error message
static func encode_error(error_message: String) -> String:
	return encode_message(MessageTypes.ERROR, {
		"message": error_message
	})

# Parse player input from decoded message data
static func parse_player_input(data: Dictionary) -> Dictionary:
	var move_dir = data.get("move_direction", {})
	return {
		"sequence": data.get("sequence", 0),
		"move_direction": Vector2(move_dir.get("x", 0.0), move_dir.get("y", 0.0)),
		"aim_angle": data.get("aim_angle", 0.0),
		"actions": data.get("actions", [])
	}
